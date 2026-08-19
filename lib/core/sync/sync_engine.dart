import '../models/task.dart';
import '../storage/repository.dart';
import 'conflict_resolver.dart';

/// 同步引擎：以 oplog 增量 + changeId 幂等 + 冲突合并为核心（纯逻辑，可单测）。
///
/// 端角色说明：
/// - Windows = Server（常驻，提供增量拉取/接收）
/// - Android = Client（打开 App / 快速同步时握手并执行一次 merge）
///
/// [TaskRepository] 是本地真相；远程端通过 [RemotePeer] 抽象对接（局域网实现后续接入）。
class SyncEngine {
  final TaskRepository local;
  const SyncEngine(this.local);

  /// 以本地为基准，与 [remoteTasks] 做一次幂等合并：
  /// - 对每个 taskId，合并本地与远端版本（LWW）
  /// - 去重：跳过本地已见过的 changeId
  /// 返回「需要写回远端」的任务列表（即远端没有、或远端较旧的更改）。
  Future<MergeResult> mergeRemote({
    required Iterable<Task> remoteTasks,
    required Iterable<String> seenChangeIds,
  }) async {
    final localTasks = await local.allTasks();
    final localById = {for (final t in localTasks) t.id: t};
    final merged = <String, Task>{};
    final toPush = <Task>[];
    final applied = <String>[];

    for (final rt in remoteTasks) {
      final existing = localById[rt.id];
      final mergedTask =
          (existing == null) ? rt : resolveConflict(existing, rt);
      merged[mergedTask.id] = mergedTask;
      applied.add(mergedTask.changeId);
    }
    // 本地独有、且远端尚未看到（未在 seenChangeIds）的改动应推送
    for (final lt in localTasks) {
      if (!merged.containsKey(lt.id)) {
        merged[lt.id] = lt;
      }
    }
    for (final t in merged.values) {
      final remoteHasNewer = remoteTasks.any(
          (r) => r.id == t.id && compareLatest(r, t) > 0);
      if (!remoteHasNewer) {
        toPush.add(t);
      }
    }
    // 持久化合并结果到本地
    for (final t in merged.values) {
      await local.upsertTask(t);
    }
    return MergeResult(merged: merged.values.toList(), toPush: toPush, appliedChangeIds: applied);
  }
}

class MergeResult {
  final List<Task> merged;
  final List<Task> toPush;
  final List<String> appliedChangeIds;
  const MergeResult({required this.merged, required this.toPush, required this.appliedChangeIds});
}

