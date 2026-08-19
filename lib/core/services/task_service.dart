import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../storage/repository.dart';

const _uuid = Uuid();

/// 任务服务：收件箱/清单 CRUD + 回收站 + 查询排序。
class TaskService {
  final TaskRepository _repo;
  TaskService(this._repo);

  Future<Task> create({
    required String title,
    String notes = '',
    String? listId,
    DueDate? due,
    TaskStatus status = TaskStatus.todo,
    String? rrule,
    List<Reminder> reminders = const [],
    int priority = 0,
  }) async {
    final now = DateTime.now().toUtc();
    final task = Task(
      id: _uuid.v4(),
      title: title,
      notes: notes,
      listId: listId,
      due: due,
      status: status,
      rrule: rrule,
      reminders: reminders,
      priority: priority,
      createdAt: now,
      updatedAt: now,
      version: 1,
      changeId: _uuid.v4(),
    );
    await _repo.upsertTask(task);
    return task;
  }

  Future<Task> edit(
    Task task, {
    String? title,
    String? notes,
    Object? listId = _sentinel,
    Object? due = _sentinel,
    TaskStatus? status,
    Object? rrule = _sentinel,
    List<Reminder>? reminders,
    int? priority,
  }) async {
    final next = task.copyWith(
      title: title,
      notes: notes,
      // Task.copyWith 的 sentinel 是模型私有实现；这里传回当前值，
      // 同时保留显式传 null 清空字段的能力。
      listId: identical(listId, _sentinel) ? task.listId : listId,
      due: identical(due, _sentinel) ? task.due : due,
      status: status,
      rrule: identical(rrule, _sentinel) ? task.rrule : rrule,
      reminders: reminders,
      priority: priority,
    );
    await _repo.upsertTask(next);
    return next;
  }

  Future<Task> setDone(Task t, bool done) =>
      edit(t, status: done ? TaskStatus.done : TaskStatus.todo);

  /// 移入回收站（软删除，会经 oplog 传播）。
  Future<Task> recycle(Task t) async {
    final removed = t.copyWith(deleted: true);
    await _repo.upsertTask(removed);
    return removed;
  }

  /// 从回收站恢复。
  Future<Task> restore(Task t) async {
    final next = t.copyWith(deleted: false);
    await _repo.upsertTask(next);
    return next;
  }

  /// 彻底删除（物理移除，不同步）。
  Future<void> deletePermanent(Task t) => _repo.removeTask(t.id);

  Future<TaskList> createList({required String name, String? color}) async {
    final list = TaskList(
      id: _uuid.v4(),
      name: name,
      color: color,
      updatedAt: DateTime.now().toUtc(),
    );
    await _repo.upsertList(list);
    return list;
  }

  Future<TaskList> editList(
    TaskList list, {
    String? name,
    String? color,
    int? sortOrder,
  }) async {
    final next = list.copyWith(
      name: name,
      color: color,
      sortOrder: sortOrder,
    );
    await _repo.upsertList(next);
    return next;
  }

  Future<void> deleteList(TaskList list) async {
    final tasks = await _repo.allTasks();
    final moved = tasks
        .where((task) => task.listId == list.id)
        .map((task) => task.copyWith(listId: null))
        .toList();
    await _repo.replaceTasksAndRemoveList(list.id, moved);
  }

  Future<List<Task>> query({
    String? search,
    String? listId,
    TaskStatus? status,
    bool includeDeleted = false,
    BySort by = BySort.dueAsc,
  }) async {
    var ts = await _repo.allTasks();
    if (!includeDeleted) ts = ts.where((t) => !t.deleted).toList();
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      ts = ts
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.notes.toLowerCase().contains(q))
          .toList();
    }
    if (listId != null) ts = ts.where((t) => t.listId == listId).toList();
    if (status != null) ts = ts.where((t) => t.status == status).toList();
    switch (by) {
      case BySort.dueAsc:
        ts.sort((a, b) => _dueKey(a.due).compareTo(_dueKey(b.due)));
      case BySort.createdDesc:
        ts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return ts;
  }

  DateTime _dueKey(DueDate? d) => d?.value ?? DateTime(9999);
}

const Object _sentinel = Object();

enum BySort { dueAsc, createdDesc }
