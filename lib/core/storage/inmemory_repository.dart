import '../models/models.dart';
import '../sync/conflict_resolver.dart';
import 'repository.dart';

/// 内存版仓库：用于测试与快速原型，接口与本地持久化实现一致。
class InMemoryRepository implements TaskRepository {
  final Map<String, Task> _tasks = {};
  final Map<String, TaskList> _lists = {};
  final Map<String, TaskTombstone> _tombstones = {};
  final List<Change> _changes = [];

  @override
  Future<List<Task>> allTasks() async => _tasks.values.toList();

  @override
  Future<List<TaskList>> allLists({bool includeDeleted = false}) async =>
      _lists.values.where((list) => includeDeleted || !list.deleted).toList();

  @override
  Future<List<TaskTombstone>> allTombstones() async =>
      _tombstones.values.toList();

  @override
  Future<void> upsertTask(Task task) async {
    _tombstones.remove(task.id);
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
  Future<void> upsertTombstone(TaskTombstone tombstone) async {
    final existing = _tombstones[tombstone.id];
    if (existing != null && compareTombstone(existing, tombstone) >= 0) {
      return;
    }
    _tasks.remove(tombstone.id);
    _tombstones[tombstone.id] = tombstone;
    _changes.add(Change(
      changeId: tombstone.changeId,
      taskId: tombstone.id,
      kind: 'delete',
      timestamp: tombstone.updatedAt,
      version: tombstone.version,
    ));
  }

  @override
  Future<void> replaceSnapshot({
    required List<Task> tasks,
    required List<TaskList> lists,
    Iterable<Change> changes = const [],
    Iterable<TaskTombstone> tombstones = const [],
  }) async {
    _tasks
      ..clear()
      ..addEntries(tasks.map((task) => MapEntry(task.id, task)));
    _lists
      ..clear()
      ..addEntries(lists.map((list) => MapEntry(list.id, list)));
    _tombstones
      ..clear()
      ..addEntries(tombstones.map((t) => MapEntry(t.id, t)));
    final known = _changes.map((change) => change.changeId).toSet();
    for (final change in changes) {
      if (known.add(change.changeId)) _changes.add(change);
    }
  }

  @override
  Future<void> replaceTasksAndRemoveList(
      String listId, List<Task> tasks) async {
    for (final task in tasks) {
      _tasks[task.id] = task;
      _changes.add(Change(
        changeId: task.changeId,
        taskId: task.id,
        kind: task.deleted ? 'delete' : 'upsert',
        timestamp: task.updatedAt,
        version: task.version,
      ));
    }
    _lists.remove(listId);
  }

  @override
  Future<void> removeList(String id) async {
    _lists.remove(id);
  }

  @override
  Future<void> removeTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<Change>> changesSince(String? cursor) async {
    final idx = cursor == null
        ? 0
        : _changes.indexWhere((c) => c.changeId == cursor) + 1;
    return idx < 0 ? _changes : _changes.skip(idx).toList();
  }
}
