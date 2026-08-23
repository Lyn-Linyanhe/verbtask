import 'package:rrule/rrule.dart';

/// 周期性任务的 RRULE 展开与"下一个实例"计算。
class RruleService {
  /// 返回严格晚于 [after] 的下一个发生时刻（UTC）；无则 null。
  /// [start] 为该系列的开始时刻（UTC），一般取任务的 createdAt。
  DateTime? nextAfter(String rruleString, DateTime after,
      {required DateTime start,
      DateTime? recurrenceUntil,
      bool localWallClock = false}) {
    final rule = _parse(rruleString);
    for (final inst
        in rule.getInstances(start: _ruleStart(start, localWallClock))) {
      final i = _actualTime(inst, localWallClock);
      if (recurrenceUntil != null && i.isAfter(recurrenceUntil)) break;
      if (i.isAfter(after)) return i;
    }
    return null;
  }

  /// 返回 [from, until) 间的发生时刻（最多 [limit] 个），便于提醒预排。
  List<DateTime> instancesBetween(
    String rruleString,
    DateTime from,
    DateTime until, {
    required DateTime start,
    int limit = 500,
    DateTime? recurrenceUntil,
    bool localWallClock = false,
  }) {
    final rule = _parse(rruleString);
    final out = <DateTime>[];
    for (final inst
        in rule.getInstances(start: _ruleStart(start, localWallClock))) {
      final i = _actualTime(inst, localWallClock);
      if (recurrenceUntil != null && i.isAfter(recurrenceUntil)) break;
      if (!i.isBefore(until)) break;
      if (!i.isBefore(from)) out.add(i);
      if (out.length >= limit) break;
    }
    return out;
  }

  RecurrenceRule _parse(String text) {
    final t = text.trim();
    final body = t.startsWith('RRULE:') ? t.substring('RRULE:'.length) : t;
    return RecurrenceRule.fromString('RRULE:$body');
  }

  /// The rrule package treats UTC fields as floating wall-clock fields.
  /// Timed tasks are stored as UTC instants, so convert their local components
  /// to a floating UTC value before expansion and convert them back afterward.
  DateTime _ruleStart(DateTime start, bool localWallClock) {
    if (!localWallClock) return start.toUtc();
    final local = start.toLocal();
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

  DateTime _actualTime(DateTime value, bool localWallClock) {
    if (!localWallClock) return value.toUtc();
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    ).toUtc();
  }
}
