import '../models/models.dart';
import '../storage/repository.dart';
import 'conflict_resolver.dart';

/// 同步引擎：以 oplog 增量 + changeId 幂等 + 冲突合并为核心（纯逻辑，可单测）。
///
/// 端角色说明：
/// - Windows = Server（常驻，提供增量拉取/接收）
/// - Android = Client（打开 App / 快速同步时握手并执行一次 merge）
class SyncEngine {
  final TaskRepository local;
  const SyncEngine(this.local);

  /// 以本地为基准，与远端做一次幂等合并：
  /// - 对每个 taskId，合并本地与远端版本（LWW，任务级）
  /// - 对每个 listId，按 updatedAt LWW
  /// - 去重：跳过本地已见过的 changeId
  /// 返回「需要写回远端」的任务/清单。
  Future<MergeResult> mergeRemote({
    required Iterable<Task> remoteTasks,
    Iterable<TaskTombstone> remoteTombstones = const [],
    required Iterable<String> seenChangeIds,
    Iterable<TaskList> remoteLists = const [],
    bool remoteSnapshotComplete = true,
  }) async {
    final localTasks = await local.allTasks();
    final localTombstones = await local.allTombstones();
    final localById = {for (final t in localTasks) t.id: t};
    final localTombstoneById = {
      for (final tombstone in localTombstones) tombstone.id: tombstone
    };
    final remoteTaskList = remoteTasks.toList();
    final remoteTombstoneList = remoteTombstones.toList();
    final remoteById = {for (final t in remoteTaskList) t.id: t};
    final remoteTombstoneById = {
      for (final tombstone in remoteTombstoneList) tombstone.id: tombstone
    };
    final seen = seenChangeIds.toSet();
    final merged = <String, Task>{};
    final mergedTombstones = <String, TaskTombstone>{
      for (final tombstone in localTombstones) tombstone.id: tombstone
    };
    final toPush = <Task>[];
    final tombstonesToPush = <TaskTombstone>[];
    final applied = <String>[];

    // 先合并永久删除，再决定远端任务是否仍有资格存在。
    for (final rt in remoteTombstoneList) {
      final localTask = localById[rt.id];
      final localTombstone = localTombstoneById[rt.id];
      if (localTask != null && compareTaskTombstone(localTask, rt) >= 0) {
        continue;
      }
      if (localTombstone == null || compareTombstone(rt, localTombstone) > 0) {
        mergedTombstones[rt.id] = rt;
        if (!seen.contains(rt.changeId)) applied.add(rt.changeId);
      }
    }

    for (final rt in remoteTaskList) {
      final tombstone = mergedTombstones[rt.id];
      if (tombstone != null && compareTaskTombstone(rt, tombstone) <= 0) {
        continue;
      }
      final existing = localById[rt.id];
      final mergedTask =
          (existing == null) ? rt : resolveConflict(existing, rt);
      merged[mergedTask.id] = mergedTask;
      if (!seen.contains(rt.changeId) && mergedTask.changeId == rt.changeId) {
        applied.add(mergedTask.changeId);
      }
    }
    for (final lt in localTasks) {
      final tombstone = mergedTombstones[lt.id];
      if (tombstone != null && compareTaskTombstone(lt, tombstone) <= 0) {
        // 远端更晚的永久删除优先于本地残留旧任务；不能把它重新放回
        // merged，也不能在后面作为本地胜出版本推回服务器。
        continue;
      }
      if (!merged.containsKey(lt.id)) {
        merged[lt.id] = lt;
      }
    }
    for (final t in merged.values) {
      final remote = remoteById[t.id];
      final remoteTombstone = remoteTombstoneById[t.id];
      final localWinsTask = remote == null
          ? (remoteSnapshotComplete || !seen.contains(t.changeId))
          : compareLatest(t, remote) > 0;
      final taskBeatsTombstone = remoteTombstone != null &&
          compareTaskTombstone(t, remoteTombstone) > 0;
      if (localWinsTask || taskBeatsTombstone) {
        toPush.add(t);
      }
    }
    for (final tombstone in mergedTombstones.values) {
      final remoteTombstone = remoteTombstoneById[tombstone.id];
      final remoteTask = remoteById[tombstone.id];
      final needsPush = remoteTombstone != null
          ? compareTombstone(tombstone, remoteTombstone) > 0
          : remoteTask != null
              ? compareTaskTombstone(remoteTask, tombstone) < 0
              : remoteSnapshotComplete && !seen.contains(tombstone.changeId);
      if (needsPush) tombstonesToPush.add(tombstone);
    }
    for (final t in merged.values) {
      final existing = localById[t.id];
      // 相同 change/version 已经是本地状态时不要再次写入 oplog。
      if (existing == null || compareLatest(existing, t) != 0) {
        await local.upsertTask(t);
      }
    }
    for (final tombstone in mergedTombstones.values) {
      final existing = localTombstoneById[tombstone.id];
      final existingTask = localById[tombstone.id];
      if ((existing == null || compareTombstone(existing, tombstone) != 0) &&
          (existingTask == null ||
              compareTaskTombstone(existingTask, tombstone) < 0)) {
        await local.upsertTombstone(tombstone);
      }
    }

    // ---- 清单合并（低基数快照段，updatedAt LWW）----
    final localLists = await local.allLists(includeDeleted: true);
    final remoteListById = {for (final l in remoteLists) l.id: l};
    final localListById = {for (final l in localLists) l.id: l};
    final listIds = {...localListById.keys, ...remoteListById.keys};
    final mergedLists = <String, TaskList>{};
    final listsToPush = <TaskList>[];
    for (final id in listIds) {
      final a = localListById[id];
      final b = remoteListById[id];
      if (a == null) {
        mergedLists[id] = b!;
      } else if (b == null) {
        mergedLists[id] = a;
        listsToPush.add(a);
      } else {
        final pick = compareListLatest(a, b) >= 0 ? a : b;
        mergedLists[id] = pick;
        if (identical(pick, a)) listsToPush.add(a);
      }
    }
    for (final l in mergedLists.values) {
      await local.upsertList(l);
    }

    return MergeResult(
      merged: merged.values.toList(),
      toPush: toPush,
      tombstonesToPush: tombstonesToPush,
      listsToPush: listsToPush,
      appliedChangeIds: applied,
    );
  }
}

class MergeResult {
  final List<Task> merged;
  final List<Task> toPush;
  final List<TaskTombstone> tombstonesToPush;
  final List<TaskList> listsToPush;
  final List<String> appliedChangeIds;
  const MergeResult({
    required this.merged,
    required this.toPush,
    this.tombstonesToPush = const [],
    required this.listsToPush,
    required this.appliedChangeIds,
  });
}
