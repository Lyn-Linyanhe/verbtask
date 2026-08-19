import '../models/models.dart';

/// 一条变更日志（oplog）记录。
class Change {
  final String changeId;
  final String? taskId;
  final String kind; // 'upsert' | 'delete'
  final DateTime timestamp;
  final int version;

  const Change({
    required this.changeId,
    this.taskId,
    required this.kind,
    required this.timestamp,
    required this.version,
  });
}

/// 任务仓库：跨端一致性的单一入口（本地实现 + 未来的 SQLite/drift 实现）。
abstract class TaskRepository {
  Future<List<Task>> allTasks();
  Future<List<TaskList>> allLists();
  Future<void> upsertTask(Task task);
  Future<void> upsertList(TaskList list);
  /// 彻底删除（物理移除，不进入 oplog 传播）。
  Future<void> removeTask(String id);
  /// 距 [cursor]（changeId）之后的本地改动；null cursor = 全量。
  Future<List<Change>> changesSince(String? cursor);
}
