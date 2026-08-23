import '../models/task.dart';
import '../rrule/rrule_service.dart';

/// 一个重复实例及其单次覆盖后的有效截止时刻。
class RecurringOccurrence {
  final DateTime occurrence;
  final DateTime? dueAt;
  final TaskOccurrenceOverride? override;

  const RecurringOccurrence({
    required this.occurrence,
    required this.dueAt,
    this.override,
  });
}

/// 纯逻辑：把一个任务实例（已解析出唯一到期时刻）映射为一组提醒触发时刻。
class ReminderScheduler {
  /// 针对一个已确定的到期时刻 [dueAt] 计算所有提醒触发时刻。
  /// [reminders] 为空 → 返回空（不提醒）。
  List<DateTime> fireTimesForDue(DateTime dueAt, List<Reminder> reminders,
      {bool dateOnly = false}) {
    if (reminders.isEmpty) return const [];
    final effectiveDue = dateOnly
        ? DateTime(dueAt.year, dueAt.month, dueAt.day, 9).toUtc()
        : dueAt.toUtc();
    final fireTimes = reminders
        .map((r) {
          if (r.isAbsolute) return r.absoluteAt!.toUtc();
          return effectiveDue.add(Duration(minutes: r.offsetMinutes)); // 负偏移=提前
        })
        .toSet()
        .toList()
      ..sort();
    return fireTimes;
  }

  /// 对重复任务：取下一个未完成实例的到期时刻进行预排。
  /// 返回 nil 表示暂无可用实例（无限期后或无法展开）。
  DateTime? nextDueForRepeating(Task task, DateTime now, RruleService rrule) {
    if (!task.isRepeating) return task.due?.value;
    final upcoming = upcomingDueForRepeating(task, now, rrule);
    return upcoming.isEmpty ? null : upcoming.first;
  }

  List<DateTime> upcomingDueForRepeating(
    Task task,
    DateTime now,
    RruleService rrule, {
    Duration window = const Duration(days: 31),
    int limit = 64,
  }) {
    return upcomingOccurrencesForRepeating(
      task,
      now,
      rrule,
      window: window,
      limit: limit,
    ).where((item) => item.dueAt != null).map((item) => item.dueAt!).toList();
  }

  List<RecurringOccurrence> upcomingOccurrencesForRepeating(
    Task task,
    DateTime now,
    RruleService rrule, {
    Duration window = const Duration(days: 31),
    int limit = 64,
  }) {
    if (!task.isRepeating || task.due == null) return const [];
    final from = task.due!.dateOnly
        // 日期型任务的 RRULE 实例锚在 UTC 午夜，但提醒按本地日历日的
        // 上午 9 点计算。先回看一天，才能在本地上午仍保留当天实例。
        ? now.toUtc().subtract(const Duration(days: 1))
        : now.toUtc();
    final candidates = rrule.instancesBetween(
      task.rrule!,
      from,
      from.add(_lookaheadWindow(task.rrule!, window)),
      start: task.due!.value,
      recurrenceUntil: task.recurrenceUntil,
      limit: limit * 2,
      localWallClock: !task.due!.dateOnly,
    );
    return candidates
        .where((instance) {
          final key = occurrenceKey(instance);
          return !task.completedOccurrences.contains(key) &&
              !task.skippedOccurrences.contains(key);
        })
        .map((instance) {
          final override = task.overrideFor(instance);
          return RecurringOccurrence(
            occurrence: instance,
            dueAt: override == null ? instance : override.due?.value,
            override: override,
          );
        })
        .take(limit)
        .toList();
  }

  /// 预排窗口不能短于一个低频重复周期，否则“每季度/每年”任务会
  /// 永远没有下一次提醒。高频任务仍受调用方的默认窗口限制。
  Duration _lookaheadWindow(String rule, Duration base) {
    final frequency = RegExp(r'(?:^|;)FREQ=([^;]+)', caseSensitive: false)
            .firstMatch(rule)
            ?.group(1)
            ?.toUpperCase() ??
        '';
    final interval = int.tryParse(
            RegExp(r'(?:^|;)INTERVAL=(\d+)', caseSensitive: false)
                    .firstMatch(rule)
                    ?.group(1) ??
                '') ??
        1;
    final gap = switch (frequency) {
      'YEARLY' => Duration(days: 366 * interval + 31),
      'MONTHLY' => Duration(days: 31 * interval + 31),
      'WEEKLY' => Duration(days: 7 * interval + 7),
      'DAILY' => Duration(days: interval + 1),
      'HOURLY' => Duration(hours: interval + 1),
      'MINUTELY' => Duration(minutes: interval + 1),
      _ => base,
    };
    return gap > base ? gap : base;
  }
}
