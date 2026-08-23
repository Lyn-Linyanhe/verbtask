import '../models/task.dart';
import '../models/task_list.dart';

/// 冲突合并：任务级 Last-write-wins，以 (version, updatedAt) 元组判定。
/// 比较结果 >0 表示 a 较新，<0 表示 b 较新，0 表示等同。
int compareLatest(Task a, Task b) {
  if (a.version != b.version) return a.version.compareTo(b.version);
  final t = a.updatedAt.compareTo(b.updatedAt);
  if (t != 0) return t;
  return a.changeId.compareTo(b.changeId);
}

int _compareParts({
  required int aVersion,
  required DateTime aUpdatedAt,
  required String aChangeId,
  required int bVersion,
  required DateTime bUpdatedAt,
  required String bChangeId,
}) {
  if (aVersion != bVersion) return aVersion.compareTo(bVersion);
  final t = aUpdatedAt.compareTo(bUpdatedAt);
  if (t != 0) return t;
  return aChangeId.compareTo(bChangeId);
}

int compareTaskTombstone(Task task, TaskTombstone tombstone) => _compareParts(
      aVersion: task.version,
      aUpdatedAt: task.updatedAt,
      aChangeId: task.changeId,
      bVersion: tombstone.version,
      bUpdatedAt: tombstone.updatedAt,
      bChangeId: tombstone.changeId,
    );

int compareTombstone(TaskTombstone a, TaskTombstone b) => _compareParts(
      aVersion: a.version,
      aUpdatedAt: a.updatedAt,
      aChangeId: a.changeId,
      bVersion: b.version,
      bUpdatedAt: b.updatedAt,
      bChangeId: b.changeId,
    );

int compareListLatest(TaskList a, TaskList b) => _compareParts(
      aVersion: a.version,
      aUpdatedAt: a.updatedAt,
      aChangeId: a.changeId,
      bVersion: b.version,
      bUpdatedAt: b.updatedAt,
      bChangeId: b.changeId,
    );

/// 返回较新的一方；冲突时按 (version, updatedAt) 选择，并提升其 version 以固化排序。
Task resolveConflict(Task a, Task b) {
  final cmp = compareLatest(a, b);
  if (cmp >= 0) return a;
  return b;
}
