/// 任务状态（看板列式）
enum TaskStatus { todo, doing, done }

/// 截止日期：支持「仅日期」或「日期+时刻」。
class DueDate {
  final DateTime value; // 统一存 UTC
  final bool dateOnly;  // true=仅日期（展示不随夏令时漂移）

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
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version; // 单调逻辑版本，用于冲突判定
  final String changeId; // 每次改动的全局唯一 id（oplog）
  final String? seriesId; // 重复任务系列标识
  final bool deleted; // true=已移入回收站

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
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    String? changeId,
    this.seriesId,
    this.deleted = false,
  }) : changeId = changeId ?? '$id-v1';

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
    Object? seriesId = _sentinel,
    bool? deleted,
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
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
      version: version + 1,
      changeId: '$id-${version + 1}',
      seriesId: identical(seriesId, _sentinel) ? this.seriesId : seriesId as String?,
      deleted: deleted ?? this.deleted,
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
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'version': version,
        'changeId': changeId,
        'seriesId': seriesId,
        'deleted': deleted,
      };

  factory Task.fromJson(Map<String, Object?> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        notes: (json['notes'] as String?) ?? '',
        listId: json['listId'] as String?,
        status: TaskStatus.values.firstWhere(
            (e) => e.name == (json['status'] as String? ?? 'todo')),
        due: json['due'] == null
            ? null
            : DueDate.fromJson(json['due'] as Map<String, Object?>),
        priority: (json['priority'] as num?)?.toInt() ?? 0,
        sortOrder: (json['sortOrder'] as num?)?.toDouble() ?? 0,
        rrule: json['rrule'] as String?,
        reminders: ((json['reminders'] as List?) ?? const [])
            .map((e) => Reminder.fromJson(e as Map<String, Object?>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
        version: (json['version'] as num?)?.toInt() ?? 1,
        changeId: json['changeId'] as String?,
        seriesId: json['seriesId'] as String?,
        deleted: (json['deleted'] as bool?) ?? false,
      );
}

const Object _sentinel = Object();
