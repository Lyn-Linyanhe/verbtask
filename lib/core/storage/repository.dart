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
  /// 当前磁盘快照的 schema 版本。旧版本由具体持久化实现迁移。
  static const currentSchemaVersion = 2;

  Future<List<Task>> allTasks();
  Future<List<TaskList>> allLists({bool includeDeleted = false});
  Future<List<TaskTombstone>> allTombstones();
  Future<void> upsertTask(Task task);
  Future<void> upsertList(TaskList list);
  Future<void> upsertTombstone(TaskTombstone tombstone);

  /// 在一次提交中替换任务和清单快照，用于导入/迁移等原子操作。
  Future<void> replaceSnapshot({
    required List<Task> tasks,
    required List<TaskList> lists,
    Iterable<Change> changes = const [],
    Iterable<TaskTombstone> tombstones = const [],
  });

  /// 一次性替换任务并移除清单，避免删除清单时出现部分迁移。
  Future<void> replaceTasksAndRemoveList(String listId, List<Task> tasks);

  /// 物理删除清单；清单内任务由业务层先移回收件箱。
  Future<void> removeList(String id);

  /// 彻底删除（物理移除，不进入 oplog 传播）。
  Future<void> removeTask(String id);

  /// 距 [cursor]（changeId）之后的本地改动；null cursor = 全量。
  Future<List<Change>> changesSince(String? cursor);
}

/// 本地数据无法安全解析时抛出的错误。
///
/// [filePath] 保留原始数据文件位置；[recoveryPath] 指向一份只读恢复副本，
/// 便于用户在修复或导入前保留证据。调用方不得把此错误当作“空仓库”处理。
class StorageLoadException implements Exception {
  final String filePath;
  final String? recoveryPath;
  final Object cause;

  const StorageLoadException({
    required this.filePath,
    required this.recoveryPath,
    required this.cause,
  });

  @override
  String toString() =>
      'StorageLoadException(file: $filePath, recovery: $recoveryPath, cause: $cause)';
}
