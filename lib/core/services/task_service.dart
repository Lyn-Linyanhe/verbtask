import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../storage/repository.dart';
import '../rrule/rrule_service.dart';

enum RecurrenceEditScope { occurrence, thisAndFuture, wholeSeries }

/// 重复编辑的提交结果。拆分系列时 [newSeries] 是当前实例及以后的新系列。
class RecurringEditResult {
  final Task series;
  final Task? newSeries;

  const RecurringEditResult({required this.series, this.newSeries});
}

const _uuid = Uuid();

/// 任务服务：收件箱/清单 CRUD + 回收站 + 查询排序。
class TaskService {
  final TaskRepository _repo;
  final Future<void> Function()? _onChanged;
  TaskService(this._repo, {Future<void> Function()? onChanged})
      : _onChanged = onChanged;

  Future<void> _notifyChanged() async {
    try {
      await _onChanged?.call();
    } catch (_) {
      // A notification failure must not roll back a successful task write.
    }
  }

  Future<Task> create({
    required String title,
    String notes = '',
    String? listId,
    DueDate? due,
    TaskStatus status = TaskStatus.todo,
    String? rrule,
    List<Reminder> reminders = const [],
    ReminderPolicy reminderPolicy = ReminderPolicy.inherit,
    int priority = 0,
  }) async {
    final now = DateTime.now().toUtc();
    final task = _newTask(
      title: title,
      notes: notes,
      listId: listId,
      due: due,
      status: status,
      rrule: rrule,
      reminders: reminders,
      reminderPolicy: reminderPolicy,
      priority: priority,
      createdAt: now,
    );
    await _repo.upsertTask(task);
    await _notifyChanged();
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
    ReminderPolicy? reminderPolicy,
    int? priority,
    Object? recurrenceUntil = _sentinel,
    Map<String, TaskOccurrenceOverride>? occurrenceOverrides,
  }) async {
    final nextRrule =
        identical(rrule, _sentinel) ? task.rrule : rrule as String?;
    final nextDue = identical(due, _sentinel) ? task.due : due as DueDate?;
    final dueWasExplicit = !identical(due, _sentinel);
    if (nextRrule != null &&
        nextRrule.trim().isNotEmpty &&
        nextDue == null &&
        (task.due != null || dueWasExplicit)) {
      throw ArgumentError('重复任务必须有截止时间');
    }
    final nextSeriesId = identical(rrule, _sentinel)
        ? task.seriesId
        : nextRrule == null
            ? null
            : task.seriesId ?? _uuid.v4();
    final ruleChanged =
        !identical(rrule, _sentinel) && !_sameRule(nextRrule, task.rrule);
    final nextOverrides = nextRrule == null || ruleChanged
        ? const <String, TaskOccurrenceOverride>{}
        : occurrenceOverrides;
    final nextRecurrenceUntil = identical(recurrenceUntil, _sentinel)
        ? task.recurrenceUntil
        : recurrenceUntil as DateTime?;
    final candidate = task.copyWith(
      title: title,
      notes: notes,
      // Task.copyWith 的 sentinel 是模型私有实现；这里传回当前值，
      // 同时保留显式传 null 清空字段的能力。
      listId: identical(listId, _sentinel) ? task.listId : listId,
      due: nextDue,
      status: status,
      rrule: nextRrule,
      reminders: reminders,
      reminderPolicy: reminderPolicy,
      priority: priority,
      seriesId: nextSeriesId,
      recurrenceUntil: nextRrule == null ? null : nextRecurrenceUntil,
      occurrenceOverrides: nextOverrides,
    );
    final next = ruleChanged
        ? candidate.copyWith(
            completedOccurrences:
                _validKeysForTask(candidate, task.completedOccurrences),
            skippedOccurrences:
                _validKeysForTask(candidate, task.skippedOccurrences),
          )
        : candidate;
    await _repo.upsertTask(next);
    await _notifyChanged();
    return next;
  }

  Future<Task> setDone(Task t, bool done) async {
    if (!t.isRepeating) {
      return edit(t, status: done ? TaskStatus.done : TaskStatus.todo);
    }
    final occurrence = _nextOccurrence(t);
    if (occurrence == null) return t;
    return completeOccurrence(t, occurrence, completed: done);
  }

  Future<Task> completeOccurrence(
    Task task,
    DateTime occurrence, {
    required bool completed,
  }) async {
    if (!task.isRepeating) {
      return edit(task, status: completed ? TaskStatus.done : TaskStatus.todo);
    }
    final key = occurrenceKey(occurrence);
    final completedKeys = Set<String>.of(task.completedOccurrences);
    final skippedKeys = Set<String>.of(task.skippedOccurrences)..remove(key);
    if (completed) {
      completedKeys.add(key);
    } else {
      completedKeys.remove(key);
    }
    final next = task.copyWith(
      completedOccurrences: completedKeys,
      skippedOccurrences: skippedKeys,
    );
    await _repo.upsertTask(next);
    await _notifyChanged();
    return next;
  }

  Future<Task> skipOccurrence(Task task, DateTime occurrence) async {
    if (!task.isRepeating) return task;
    final key = occurrenceKey(occurrence);
    final skippedKeys = Set<String>.of(task.skippedOccurrences)..add(key);
    final completedKeys = Set<String>.of(task.completedOccurrences)
      ..remove(key);
    final next = task.copyWith(
      completedOccurrences: completedKeys,
      skippedOccurrences: skippedKeys,
    );
    await _repo.upsertTask(next);
    await _notifyChanged();
    return next;
  }

  /// 应用重复任务的编辑范围。
  ///
  /// 单次编辑把完整内容保存到实例覆盖；此次及以后编辑会把原系列截断，
  /// 并创建一个从当前实例开始的新系列。这样同步后仍能保留每个实例的
  /// 原始 occurrence 身份，而不是把编辑伪装成“跳过一次”。
  Future<RecurringEditResult> editRecurring(
    Task task, {
    required RecurrenceEditScope scope,
    DateTime? occurrence,
    String? title,
    String? notes,
    Object? listId = _sentinel,
    Object? due = _sentinel,
    TaskStatus? status,
    Object? rrule = _sentinel,
    List<Reminder>? reminders,
    ReminderPolicy? reminderPolicy,
    int? priority,
  }) async {
    if (!task.isRepeating || scope == RecurrenceEditScope.wholeSeries) {
      final next = await edit(
        task,
        title: title,
        notes: notes,
        listId: listId,
        due: due,
        status: status,
        rrule: identical(rrule, _sentinel) ? task.rrule : rrule,
        reminders: reminders,
        reminderPolicy: reminderPolicy,
        priority: priority,
        // 拆分后的旧段仍有自己的边界；清除它会让旧段与新段重叠。
        recurrenceUntil: task.recurrenceUntil,
        occurrenceOverrides: const {},
      );
      return RecurringEditResult(series: next);
    }
    if (occurrence == null) {
      throw ArgumentError('重复任务的实例编辑必须提供 occurrence');
    }
    final at = occurrence.toUtc();
    if (!_isValidOccurrence(task, at)) {
      throw ArgumentError('实例不属于当前重复规则');
    }
    final key = occurrenceKey(at);
    if (scope == RecurrenceEditScope.occurrence) {
      final previous = task.overrideFor(at);
      final effectiveDue = identical(due, _sentinel)
          ? previous != null
              ? previous.due
              : _dueForOccurrence(task, at)
          : due as DueDate?;
      final override = TaskOccurrenceOverride(
        title: title ?? previous?.title ?? task.title,
        notes: notes ?? previous?.notes ?? task.notes,
        listId: identical(listId, _sentinel)
            ? previous != null
                ? previous.listId
                : task.listId
            : listId as String?,
        status: status ?? previous?.status ?? task.status,
        due: effectiveDue,
        priority: priority ?? previous?.priority ?? task.priority,
        reminders: reminders ?? previous?.reminders ?? task.reminders,
        reminderPolicy:
            reminderPolicy ?? previous?.reminderPolicy ?? task.reminderPolicy,
      );
      final overrides =
          Map<String, TaskOccurrenceOverride>.of(task.occurrenceOverrides)
            ..[key] = override;
      final completed = Set<String>.of(task.completedOccurrences)..remove(key);
      final skipped = Set<String>.of(task.skippedOccurrences)..remove(key);
      final next = task.copyWith(
        completedOccurrences: completed,
        skippedOccurrences: skipped,
        occurrenceOverrides: overrides,
      );
      await _repo.upsertTask(next);
      await _notifyChanged();
      return RecurringEditResult(series: next);
    }
    final start = task.due?.value;
    if (start == null || task.rrule == null) {
      throw ArgumentError('重复任务的实例编辑必须有截止时间和重复规则');
    }
    final previous = _previousOccurrence(task, at);
    final oldCompleted = _validKeysBefore(task, task.completedOccurrences, at);
    final oldSkipped = _validKeysBefore(task, task.skippedOccurrences, at);
    final oldOverrides =
        _validOverridesBefore(task, task.occurrenceOverrides, at);

    final nextRrule =
        identical(rrule, _sentinel) ? task.rrule : rrule as String?;
    if (nextRrule == null || nextRrule.trim().isEmpty) {
      throw ArgumentError('此次及以后编辑必须保留重复规则');
    }
    final nextDue = identical(due, _sentinel)
        ? DueDate(at, dateOnly: task.due?.dateOnly ?? false)
        : due as DueDate?;
    if (nextDue == null) {
      throw ArgumentError('此次及以后编辑必须有截止时间');
    }
    final futureRrule = _sameRule(nextRrule, task.rrule)
        ? _remainingCountRule(
            nextRrule,
            start,
            at,
            localWallClock: !(task.due?.dateOnly ?? false),
          )
        : nextRrule;
    final oldSeries = task.copyWith(
      recurrenceUntil: previous,
      completedOccurrences: oldCompleted,
      skippedOccurrences: oldSkipped,
      occurrenceOverrides: oldOverrides,
      deleted: previous == null,
    );
    final future = _newTask(
      title: title ?? task.overrideFor(at)?.title ?? task.title,
      notes: notes ?? task.overrideFor(at)?.notes ?? task.notes,
      listId: identical(listId, _sentinel)
          ? task.overrideFor(at)?.listId ?? task.listId
          : listId as String?,
      due: nextDue,
      status: status ?? task.overrideFor(at)?.status ?? task.status,
      rrule: futureRrule,
      reminders: reminders ?? task.overrideFor(at)?.reminders ?? task.reminders,
      reminderPolicy: reminderPolicy ??
          task.overrideFor(at)?.reminderPolicy ??
          task.reminderPolicy,
      priority: priority ?? task.overrideFor(at)?.priority ?? task.priority,
      createdAt: DateTime.now().toUtc(),
      recurrenceUntil: task.recurrenceUntil,
      requireDue: true,
    );
    if (!_isValidOccurrence(future, nextDue.value)) {
      throw ArgumentError('新的截止时间不符合重复规则');
    }
    final futureCompleted = _remapKeysForFuture(
      task,
      future,
      task.completedOccurrences,
      at,
    );
    final futureSkipped = _remapKeysForFuture(
      task,
      future,
      task.skippedOccurrences,
      at,
    );
    final futureOverrides = _remapOverridesForFuture(
      task,
      future,
      task.occurrenceOverrides,
      at,
    );
    final newSeries = futureCompleted.isEmpty &&
            futureSkipped.isEmpty &&
            futureOverrides.isEmpty
        ? future
        : future.copyWith(
            completedOccurrences: futureCompleted,
            skippedOccurrences: futureSkipped,
            occurrenceOverrides: futureOverrides,
          );
    final existingTasks = await _repo.allTasks();
    final lists = await _repo.allLists(includeDeleted: true);
    final tombstones = await _repo.allTombstones();
    final nextTasks = existingTasks.where((item) => item.id != task.id).toList()
      ..add(oldSeries)
      ..add(newSeries);
    await _repo.replaceSnapshot(
      tasks: nextTasks,
      lists: lists,
      tombstones: tombstones,
      changes: [_changeFor(oldSeries), _changeFor(newSeries)],
    );
    await _notifyChanged();
    return RecurringEditResult(series: oldSeries, newSeries: newSeries);
  }

  Task _newTask({
    required String title,
    required String notes,
    required String? listId,
    required DueDate? due,
    required TaskStatus status,
    required String? rrule,
    required List<Reminder> reminders,
    required ReminderPolicy reminderPolicy,
    required int priority,
    required DateTime createdAt,
    DateTime? recurrenceUntil,
    bool requireDue = false,
  }) {
    if (requireDue && rrule != null && rrule.trim().isNotEmpty && due == null) {
      throw ArgumentError('重复任务必须有截止时间');
    }
    return Task(
      id: _uuid.v4(),
      title: title,
      notes: notes,
      listId: listId,
      due: due,
      status: status,
      rrule: rrule,
      reminders: reminders,
      reminderPolicy: reminderPolicy,
      priority: priority,
      createdAt: createdAt,
      updatedAt: createdAt,
      version: 1,
      changeId: _uuid.v4(),
      seriesId: rrule == null || rrule.trim().isEmpty ? null : _uuid.v4(),
      recurrenceUntil: recurrenceUntil,
    );
  }

  Change _changeFor(Task task) => Change(
        changeId: task.changeId,
        taskId: task.id,
        kind: task.deleted ? 'delete' : 'upsert',
        timestamp: task.updatedAt,
        version: task.version,
      );

  DueDate _dueForOccurrence(Task task, DateTime occurrence) {
    final dateOnly = task.due?.dateOnly ?? false;
    return dateOnly
        ? DueDate(
            DateTime.utc(occurrence.year, occurrence.month, occurrence.day),
            dateOnly: true,
          )
        : DueDate(occurrence);
  }

  DateTime? _previousOccurrence(Task task, DateTime occurrence) {
    final start = task.due?.value;
    if (start == null || task.rrule == null) return null;
    final candidates = RruleService().instancesBetween(
      task.rrule!,
      start,
      occurrence,
      start: start,
      recurrenceUntil: task.recurrenceUntil,
      limit: 10000,
      localWallClock: !(task.due?.dateOnly ?? false),
    );
    final before = candidates
        .where((candidate) => candidate.isBefore(occurrence))
        .toList();
    return before.isEmpty ? null : before.last;
  }

  Set<String> _validKeysBefore(
      Task task, Iterable<String> keys, DateTime boundary) {
    return keys
        .map(_parseOccurrence)
        .whereType<DateTime>()
        .where((value) =>
            value.isBefore(boundary) && _isValidOccurrence(task, value))
        .map(occurrenceKey)
        .toSet();
  }

  Set<String> _validKeysForTask(Task task, Iterable<String> keys) {
    return keys
        .map(_parseOccurrence)
        .whereType<DateTime>()
        .where((value) => _isValidOccurrence(task, value))
        .map(occurrenceKey)
        .toSet();
  }

  Set<String> _remapKeysForFuture(
    Task source,
    Task target,
    Iterable<String> keys,
    DateTime boundary,
  ) {
    final mapping = _futureKeyMapping(source, target, keys, boundary);
    return keys
        .map(_parseOccurrence)
        .whereType<DateTime>()
        .where((value) =>
            !value.isBefore(boundary) && !value.isAtSameMomentAs(boundary))
        .map(occurrenceKey)
        .map((key) => mapping[key])
        .whereType<String>()
        .toSet();
  }

  Map<String, TaskOccurrenceOverride> _remapOverridesForFuture(
    Task source,
    Task target,
    Map<String, TaskOccurrenceOverride> overrides,
    DateTime boundary,
  ) {
    final mapping = _futureKeyMapping(
      source,
      target,
      overrides.keys,
      boundary,
    );
    final output = <String, TaskOccurrenceOverride>{};
    for (final entry in overrides.entries) {
      final value = _parseOccurrence(entry.key);
      if (value == null ||
          value.isBefore(boundary) ||
          value.isAtSameMomentAs(boundary)) {
        continue;
      }
      final nextKey = mapping[occurrenceKey(value)];
      if (nextKey != null) output[nextKey] = entry.value;
    }
    return output;
  }

  Map<String, String> _futureKeyMapping(
    Task source,
    Task target,
    Iterable<String> keys,
    DateTime boundary,
  ) {
    final sourceStart = source.due?.value;
    final sourceRule = source.rrule;
    final targetStart = target.due?.value;
    final targetRule = target.rrule;
    if (sourceStart == null ||
        sourceRule == null ||
        targetStart == null ||
        targetRule == null) {
      return const {};
    }
    final requested = keys
        .map(_parseOccurrence)
        .whereType<DateTime>()
        .where((value) =>
            !value.isBefore(boundary) && _isValidOccurrence(source, value))
        .toList();
    if (requested.isEmpty) return const {};
    requested.sort();
    final sourceLast = requested.last;
    final sourceOccurrences = RruleService().instancesBetween(
      sourceRule,
      boundary,
      sourceLast.add(const Duration(microseconds: 1)),
      start: sourceStart,
      recurrenceUntil: source.recurrenceUntil,
      limit: 10000,
      localWallClock: !(source.due?.dateOnly ?? false),
    );
    final targetOccurrences = RruleService().instancesBetween(
      targetRule,
      targetStart,
      DateTime.utc(9999, 12, 31, 23, 59, 59, 999999),
      start: targetStart,
      recurrenceUntil: target.recurrenceUntil,
      limit: sourceOccurrences.length,
      localWallClock: !(target.due?.dateOnly ?? false),
    );
    final output = <String, String>{};
    for (var i = 0;
        i < sourceOccurrences.length && i < targetOccurrences.length;
        i++) {
      output[occurrenceKey(sourceOccurrences[i])] =
          occurrenceKey(targetOccurrences[i]);
    }
    return output;
  }

  Map<String, TaskOccurrenceOverride> _validOverridesBefore(Task task,
      Map<String, TaskOccurrenceOverride> overrides, DateTime boundary) {
    return _validOverrides(task, overrides, boundary, includeBoundary: false);
  }

  Map<String, TaskOccurrenceOverride> _validOverrides(
    Task task,
    Map<String, TaskOccurrenceOverride> overrides,
    DateTime boundary, {
    required bool includeBoundary,
  }) {
    final output = <String, TaskOccurrenceOverride>{};
    for (final entry in overrides.entries) {
      final value = _parseOccurrence(entry.key);
      if (value == null ||
          (includeBoundary
              ? value.isBefore(boundary)
              : !value.isBefore(boundary)) ||
          !_isValidOccurrence(task, value)) {
        continue;
      }
      output[occurrenceKey(value)] = entry.value;
    }
    return output;
  }

  DateTime? _parseOccurrence(String value) => DateTime.tryParse(value)?.toUtc();

  bool _isValidOccurrence(Task task, DateTime occurrence) {
    final start = task.due?.value;
    final rule = task.rrule;
    if (start == null || rule == null || occurrence.isBefore(start)) {
      return false;
    }
    final end = occurrence.add(const Duration(microseconds: 1));
    return RruleService()
        .instancesBetween(
          rule,
          occurrence,
          end,
          start: start,
          recurrenceUntil: task.recurrenceUntil,
          limit: 1,
          localWallClock: !(task.due?.dateOnly ?? false),
        )
        .any((candidate) => candidate == occurrence);
  }

  bool _sameRule(String? left, String? right) {
    if (left == null || right == null) return left == right;
    String normalize(String value) {
      final trimmed = value.trim();
      return trimmed.startsWith('RRULE:')
          ? trimmed.substring('RRULE:'.length).toUpperCase()
          : trimmed.toUpperCase();
    }

    return normalize(left) == normalize(right);
  }

  String _remainingCountRule(String? rule, DateTime start, DateTime occurrence,
      {required bool localWallClock}) {
    if (rule == null) return '';
    final countMatch =
        RegExp(r'COUNT=(\d+)', caseSensitive: false).firstMatch(rule);
    if (countMatch == null) return rule;
    final total = int.parse(countMatch.group(1)!);
    final completedBeforeSplit = RruleService()
        .instancesBetween(
          rule,
          start,
          occurrence,
          start: start,
          limit: total + 1,
          localWallClock: localWallClock,
        )
        .length;
    final remaining = (total - completedBeforeSplit).clamp(1, total);
    return rule.replaceFirst(
      RegExp(r'COUNT=\d+', caseSensitive: false),
      'COUNT=$remaining',
    );
  }

  DateTime? _nextOccurrence(Task task) {
    final start = task.due?.value;
    if (start == null || task.rrule == null) return null;
    final now = DateTime.now().toUtc();
    final until = now.add(const Duration(days: 366));
    final instances = RruleService().instancesBetween(
      task.rrule!,
      now,
      until,
      start: start,
      recurrenceUntil: task.recurrenceUntil,
      limit: 1000,
      localWallClock: !(task.due?.dateOnly ?? false),
    );
    for (final instance in instances) {
      final key = occurrenceKey(instance);
      if (!task.completedOccurrences.contains(key) &&
          !task.skippedOccurrences.contains(key)) {
        return instance;
      }
    }
    return null;
  }

  /// 移入回收站（软删除，会经 oplog 传播）。
  Future<Task> recycle(Task t) async {
    final removed = t.copyWith(deleted: true);
    await _repo.upsertTask(removed);
    await _notifyChanged();
    return removed;
  }

  /// 从回收站恢复。
  Future<Task> restore(Task t) async {
    final next = t.copyWith(deleted: false);
    await _repo.upsertTask(next);
    await _notifyChanged();
    return next;
  }

  /// 彻底删除：从本地任务表移除，但留下同步墓碑避免旧设备复活。
  Future<void> deletePermanent(Task t) async {
    await _repo.upsertTombstone(TaskTombstone.fromTask(t));
    await _notifyChanged();
  }

  Future<TaskList> createList({required String name, String? color}) async {
    final list = TaskList(
      id: _uuid.v4(),
      name: name,
      color: color,
      updatedAt: DateTime.now().toUtc(),
    );
    await _repo.upsertList(list);
    await _notifyChanged();
    return list;
  }

  Future<List<TaskList>> allLists() => _repo.allLists();

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
    await _notifyChanged();
    return next;
  }

  Future<void> deleteList(TaskList list) async {
    final tasks = await _repo.allTasks();
    final moved = tasks
        .where((task) => task.listId == list.id)
        .map((task) => task.copyWith(listId: null))
        .toList();
    await _repo.replaceTasksAndRemoveList(list.id, moved);
    await _repo.upsertList(list.copyWith(deleted: true));
    await _notifyChanged();
  }

  Future<List<Task>> query({
    String? search,
    String? listId,
    bool inboxOnly = false,
    TaskStatus? status,
    bool includeDeleted = false,
    bool includeDone = true,
    DateTime? dueFrom,
    DateTime? dueTo,
    BySort by = BySort.dueAsc,
  }) async {
    var ts = await _repo.allTasks();
    if (!includeDeleted) ts = ts.where((t) => !t.deleted).toList();
    if (!includeDone && status != TaskStatus.done) {
      ts = ts.where((t) => t.status != TaskStatus.done).toList();
    }
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      ts = ts
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.notes.toLowerCase().contains(q))
          .toList();
    }
    if (inboxOnly) {
      ts = ts.where((t) => t.listId == null).toList();
    } else if (listId != null) {
      ts = ts.where((t) => t.listId == listId).toList();
    }
    if (status != null) ts = ts.where((t) => t.status == status).toList();
    if (dueFrom != null || dueTo != null) {
      ts = ts.where((t) {
        final due = t.due?.value;
        if (due == null) return false;
        if (dueFrom != null && due.isBefore(dueFrom)) return false;
        if (dueTo != null && !due.isBefore(dueTo)) return false;
        return true;
      }).toList();
    }
    switch (by) {
      case BySort.dueAsc:
        ts.sort((a, b) => _dueKey(a.due).compareTo(_dueKey(b.due)));
      case BySort.createdDesc:
        ts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case BySort.titleAsc:
        ts.sort((a, b) {
          final byTitle =
              a.title.toLowerCase().compareTo(b.title.toLowerCase());
          return byTitle == 0 ? a.createdAt.compareTo(b.createdAt) : byTitle;
        });
    }
    return ts;
  }

  DateTime _dueKey(DueDate? d) => d?.value ?? DateTime(9999);
}

const Object _sentinel = Object();

enum BySort { dueAsc, createdDesc, titleAsc }
