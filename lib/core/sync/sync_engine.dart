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
    required Iterable<String> seenChangeIds,
    Iterable<TaskList> remoteLists = const [],
  }) async {
    final localTasks = await local.allTasks();
    final localById = {for (final t in localTasks) t.id: t};
    final seen = seenChangeIds.toSet();
    final merged = <String, Task>{};
    final toPush = <Task>[];
    final applied = <String>[];

    for (final rt in remoteTasks) {
      final existing = localById[rt.id];
      final mergedTask =
          (existing == null) ? rt : resolveConflict(existing, rt);
      merged[mergedTask.id] = mergedTask;
      if (!seen.contains(mergedTask.changeId)) {
        applied.add(mergedTask.changeId);
      }
    }
    for (final lt in localTasks) {
      if (!merged.containsKey(lt.id)) {
        merged[lt.id] = lt;
      }
    }
    for (final t in merged.values) {
      final remoteHasNewer =
          remoteTasks.any((r) => r.id == t.id && compareLatest(r, t) > 0);
      if (!remoteHasNewer) {
        toPush.add(t);
      }
    }
    for (final t in merged.values) {
      await local.upsertTask(t);
    }

    // ---- 清单合并（低基数快照段，updatedAt LWW）----
    final localLists = await local.allLists();
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
        final pick = a.updatedAt.compareTo(b.updatedAt) >= 0 ? a : b;
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
      listsToPush: listsToPush,
      appliedChangeIds: applied,
    );
  }
}

class MergeResult {
  final List<Task> merged;
  final List<Task> toPush;
  final List<TaskList> listsToPush;
  final List<String> appliedChangeIds;
  const MergeResult({
    required this.merged,
    required this.toPush,
    required this.listsToPush,
    required this.appliedChangeIds,
  });
}
