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
      createdAt: now,
      updatedAt: now,
      version: 1,
      changeId: null,
    );
    await _repo.upsertTask(task);
    return task;
  }

  Future<Task> edit(Task task, {
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
      listId: listId,
      due: due,
      status: status,
      rrule: rrule,
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
      ts = ts.where((t) =>
          t.title.toLowerCase().contains(q) || t.notes.toLowerCase().contains(q)).toList();
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
