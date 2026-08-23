import 'package:uuid/uuid.dart';

/// 任务状态（看板列式）
enum TaskStatus { todo, doing, done }

/// 任务提醒策略：继承全局默认、任务级开启或任务级明确关闭。
enum ReminderPolicy { inherit, enabled, disabled }

/// 截止日期：支持「仅日期」或「日期+时刻」。
class DueDate {
  final DateTime value; // 统一存 UTC
  final bool dateOnly; // true=仅日期（展示不随夏令时漂移）

  const DueDate(this.value, {this.dateOnly = false});

  DueDate copyWith({DateTime? value, bool? dateOnly}) =>
      DueDate(value ?? this.value, dateOnly: dateOnly ?? this.dateOnly);

  Map<String, Object?> toJson() => {
        'value': value.toUtc().toIso8601String(),
        'dateOnly': dateOnly,
      };

  factory DueDate.fromJson(Map<String, Object?> json) => DueDate(
        DateTime.parse(json['value'] as String).toUtc(),
        dateOnly: (json['dateOnly'] as bool?) ?? false,
      );
}

/// 提醒：相对到期提前量或指定绝对时刻。
class Reminder {
  final String id;
  final int offsetMinutes; // 负数=到期前 N 分钟；0=到期时刻
  final DateTime? absoluteAt; // 非空时表示绝对时刻提醒

  const Reminder({required this.id, this.offsetMinutes = 0, this.absoluteAt});

  bool get isAbsolute => absoluteAt != null;

  Map<String, Object?> toJson() => {
        'id': id,
        'offsetMinutes': offsetMinutes,
        'absoluteAt': absoluteAt?.toUtc().toIso8601String(),
      };

  factory Reminder.fromJson(Map<String, Object?> json) => Reminder(
        id: json['id'] as String,
        offsetMinutes: (json['offsetMinutes'] as num?)?.toInt() ?? 0,
        absoluteAt: json['absoluteAt'] == null
            ? null
            : DateTime.parse(json['absoluteAt'] as String).toUtc(),
      );
}

final _taskChangeUuid = Uuid();

/// 单个重复实例的内容覆盖。键是原始重复 occurrence 的 UTC ISO 字符串，
/// 因此修改后的截止时间变化不会丢失该实例在系列中的身份。
class TaskOccurrenceOverride {
  final String title;
  final String notes;
  final String? listId;
  final TaskStatus status;
  final DueDate? due;
  final int priority;
  final List<Reminder> reminders;
  final ReminderPolicy reminderPolicy;

  const TaskOccurrenceOverride({
    required this.title,
    this.notes = '',
    this.listId,
    this.status = TaskStatus.todo,
    this.due,
    this.priority = 0,
    this.reminders = const [],
    this.reminderPolicy = ReminderPolicy.inherit,
  });

  Map<String, Object?> toJson() => {
        'title': title,
        'notes': notes,
        'listId': listId,
        'status': status.name,
        'due': due?.toJson(),
        'priority': priority,
        'reminders': reminders.map((r) => r.toJson()).toList(),
        'reminderPolicy': reminderPolicy.name,
      };

  factory TaskOccurrenceOverride.fromJson(Map<String, Object?> json) {
    final rawPolicy = json['reminderPolicy'] as String?;
    final reminders = ((json['reminders'] as List?) ?? const [])
        .map((e) => Reminder.fromJson(e as Map<String, Object?>))
        .toList();
    return TaskOccurrenceOverride(
      title: json['title'] as String,
      notes: (json['notes'] as String?) ?? '',
      listId: json['listId'] as String?,
      status: TaskStatus.values.firstWhere(
        (value) => value.name == (json['status'] as String? ?? 'todo'),
        orElse: () => TaskStatus.todo,
      ),
      due: json['due'] == null
          ? null
          : DueDate.fromJson(json['due'] as Map<String, Object?>),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      reminders: reminders,
      reminderPolicy: rawPolicy == null
          ? (reminders.isEmpty
              ? ReminderPolicy.inherit
              : ReminderPolicy.enabled)
          : ReminderPolicy.values.firstWhere(
              (value) => value.name == rawPolicy,
              orElse: () => ReminderPolicy.inherit,
            ),
    );
  }
}

/// 任务实体。所有跨端同步依赖 id / version / updatedAt / changeId。
class Task {
  final String id;
  final String title;
  final String notes;
  final String? listId; // null = 收件箱
  final TaskStatus status;
  final DueDate? due;
  final int priority;
  final double sortOrder;
  final String? rrule; // RRULE 字符串；null=非重复
  final List<Reminder> reminders;
  final ReminderPolicy reminderPolicy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version; // 单调逻辑版本，用于冲突判定
  final String changeId; // 每次改动的全局唯一 id（oplog）
  final String? seriesId; // 重复任务系列标识
  final DateTime? recurrenceUntil; // 此次及以后拆分时旧系列的最后一个实例
  final bool deleted; // true=已移入回收站
  final Set<String> completedOccurrences;
  final Set<String> skippedOccurrences;
  final Map<String, TaskOccurrenceOverride> occurrenceOverrides;

  const Task({
    required this.id,
    required this.title,
    this.notes = '',
    this.listId,
    this.status = TaskStatus.todo,
    this.due,
    this.priority = 0,
    this.sortOrder = 0,
    this.rrule,
    this.reminders = const [],
    this.reminderPolicy = ReminderPolicy.inherit,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    String? changeId,
    this.seriesId,
    this.recurrenceUntil,
    this.deleted = false,
    this.completedOccurrences = const {},
    this.skippedOccurrences = const {},
    this.occurrenceOverrides = const {},
  }) : changeId = changeId ?? '$id-v1'; // 旧 JSON 缺失时保留可读性；新写入由 service 传 UUID。

  bool get isInInbox => listId == null;
  bool get isRepeating => rrule != null && rrule!.isNotEmpty;

  Task copyWith({
    String? title,
    String? notes,
    Object? listId = _sentinel,
    TaskStatus? status,
    Object? due = _sentinel,
    int? priority,
    double? sortOrder,
    Object? rrule = _sentinel,
    List<Reminder>? reminders,
    ReminderPolicy? reminderPolicy,
    Object? seriesId = _sentinel,
    Object? recurrenceUntil = _sentinel,
    bool? deleted,
    Set<String>? completedOccurrences,
    Set<String>? skippedOccurrences,
    Map<String, TaskOccurrenceOverride>? occurrenceOverrides,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      listId: identical(listId, _sentinel) ? this.listId : listId as String?,
      status: status ?? this.status,
      due: identical(due, _sentinel) ? this.due : due as DueDate?,
      priority: priority ?? this.priority,
      sortOrder: sortOrder ?? this.sortOrder,
      rrule: identical(rrule, _sentinel) ? this.rrule : rrule as String?,
      reminders: reminders ?? this.reminders,
      reminderPolicy: reminderPolicy ?? this.reminderPolicy,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
      version: version + 1,
      changeId: _taskChangeUuid.v4(),
      seriesId:
          identical(seriesId, _sentinel) ? this.seriesId : seriesId as String?,
      recurrenceUntil: identical(recurrenceUntil, _sentinel)
          ? this.recurrenceUntil
          : recurrenceUntil as DateTime?,
      deleted: deleted ?? this.deleted,
      completedOccurrences: completedOccurrences ?? this.completedOccurrences,
      skippedOccurrences: skippedOccurrences ?? this.skippedOccurrences,
      occurrenceOverrides: occurrenceOverrides ?? this.occurrenceOverrides,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'listId': listId,
        'status': status.name,
        'due': due?.toJson(),
        'priority': priority,
        'sortOrder': sortOrder,
        'rrule': rrule,
        'reminders': reminders.map((r) => r.toJson()).toList(),
        'reminderPolicy': reminderPolicy.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'version': version,
        'changeId': changeId,
        'seriesId': seriesId,
        'recurrenceUntil': recurrenceUntil?.toUtc().toIso8601String(),
        'deleted': deleted,
        'completedOccurrences': completedOccurrences.toList()..sort(),
        'skippedOccurrences': skippedOccurrences.toList()..sort(),
        'occurrenceOverrides': {
          for (final entry in occurrenceOverrides.entries)
            entry.key: entry.value.toJson(),
        },
      };

  factory Task.fromJson(Map<String, Object?> json) {
    final id = json['id'] as String;
    final rawRrule = json['rrule'] as String?;
    final rawSeriesId = json['seriesId'] as String?;
    final reminders = ((json['reminders'] as List?) ?? const [])
        .map((e) => Reminder.fromJson(e as Map<String, Object?>))
        .toList();
    final rawPolicy = json['reminderPolicy'] as String?;
    final policy = rawPolicy == null
        ? (reminders.isEmpty ? ReminderPolicy.inherit : ReminderPolicy.enabled)
        : ReminderPolicy.values.firstWhere(
            (value) => value.name == rawPolicy,
            orElse: () => ReminderPolicy.inherit,
          );
    return Task(
      id: id,
      title: json['title'] as String,
      notes: (json['notes'] as String?) ?? '',
      listId: json['listId'] as String?,
      status: TaskStatus.values
          .firstWhere((e) => e.name == (json['status'] as String? ?? 'todo')),
      due: json['due'] == null
          ? null
          : DueDate.fromJson(json['due'] as Map<String, Object?>),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sortOrder'] as num?)?.toDouble() ?? 0,
      rrule: rawRrule,
      reminders: reminders,
      reminderPolicy: policy,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      version: (json['version'] as num?)?.toInt() ?? 1,
      changeId: json['changeId'] as String?,
      // v1 重复任务没有 seriesId；用稳定的任务 id 迁移，避免后续实例编辑
      // 无法识别它所属的系列。非重复任务继续保持 null。
      seriesId: rawSeriesId ??
          (rawRrule != null && rawRrule.trim().isNotEmpty ? id : null),
      recurrenceUntil: json['recurrenceUntil'] == null
          ? null
          : DateTime.parse(json['recurrenceUntil'] as String).toUtc(),
      deleted: (json['deleted'] as bool?) ?? false,
      completedOccurrences: Set<String>.from(
          (json['completedOccurrences'] as List?)?.whereType<String>() ??
              const <String>[]),
      skippedOccurrences: Set<String>.from(
          (json['skippedOccurrences'] as List?)?.whereType<String>() ??
              const <String>[]),
      occurrenceOverrides:
          _decodeOccurrenceOverrides(json['occurrenceOverrides'] as Map?),
    );
  }

  TaskOccurrenceOverride? overrideFor(DateTime occurrence) =>
      occurrenceOverrides[occurrenceKey(occurrence)];
}

Map<String, TaskOccurrenceOverride> _decodeOccurrenceOverrides(Map? raw) {
  if (raw == null) return const {};
  final output = <String, TaskOccurrenceOverride>{};
  for (final entry in raw.entries) {
    if (entry.key is! String || entry.value is! Map) continue;
    output[entry.key as String] = TaskOccurrenceOverride.fromJson(
      Map<String, Object?>.from(entry.value as Map),
    );
  }
  return output;
}

String occurrenceKey(DateTime occurrence) =>
    occurrence.toUtc().toIso8601String();

/// 彻底删除后的同步墓碑。它不出现在任务列表中，但会保留版本信息，
/// 防止另一台设备的旧任务在同步时重新出现。
class TaskTombstone {
  final String id;
  final DateTime updatedAt;
  final int version;
  final String changeId;

  const TaskTombstone({
    required this.id,
    required this.updatedAt,
    required this.version,
    required this.changeId,
  });

  factory TaskTombstone.fromTask(Task task) => TaskTombstone(
        id: task.id,
        updatedAt: DateTime.now().toUtc(),
        version: task.version + 1,
        changeId: _taskChangeUuid.v4(),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'version': version,
        'changeId': changeId,
      };

  factory TaskTombstone.fromJson(Map<String, Object?> json) => TaskTombstone(
        id: json['id'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
        version: (json['version'] as num?)?.toInt() ?? 1,
        changeId: json['changeId'] as String,
      );
}

const Object _sentinel = Object();
