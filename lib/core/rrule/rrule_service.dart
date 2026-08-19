import 'package:rrule/rrule.dart';

/// 周期性任务的 RRULE 展开与"下一个实例"计算。
class RruleService {
  /// 返回严格晚于 [after] 的下一个发生时刻（UTC）；无则 null。
  /// [start] 为该系列的开始时刻（UTC），一般取任务的 createdAt。
  DateTime? nextAfter(String rruleString, DateTime after, {required DateTime start}) {
    final rule = _parse(rruleString);
    for (final inst in rule.getInstances(start: start.toUtc())) {
      final i = inst.toUtc();
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
  }) {
    final rule = _parse(rruleString);
    final out = <DateTime>[];
    for (final inst in rule.getInstances(start: start.toUtc())) {
      final i = inst.toUtc();
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
}

