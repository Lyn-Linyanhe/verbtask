import '../models/models.dart';
import 'repository.dart';

/// 内存版仓库：用于测试与快速原型，接口与本地持久化实现一致。
class InMemoryRepository implements TaskRepository {
  final Map<String, Task> _tasks = {};
  final Map<String, TaskList> _lists = {};
  final List<Change> _changes = [];

  @override
  Future<List<Task>> allTasks() async => _tasks.values.toList();

  @override
  Future<List<TaskList>> allLists() async => _lists.values.toList();

  @override
  Future<void> upsertTask(Task task) async {
    _tasks[task.id] = task;
    _changes.add(Change(
      changeId: task.changeId,
      taskId: task.id,
      kind: task.deleted ? 'delete' : 'upsert',
      timestamp: task.updatedAt,
      version: task.version,
    ));
  }

  @override
  Future<void> upsertList(TaskList list) async {
    _lists[list.id] = list;
  }

  @override
  Future<void> removeTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<Change>> changesSince(String? cursor) async {
    final idx = cursor == null ? 0 : _changes.indexWhere((c) => c.changeId == cursor) + 1;
    return idx < 0 ? _changes : _changes.skip(idx).toList();
  }
}
