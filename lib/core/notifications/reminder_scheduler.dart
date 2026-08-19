import '../models/task.dart';
import '../rrule/rrule_service.dart';

/// 纯逻辑：把一个任务实例（已解析出唯一到期时刻）映射为一组提醒触发时刻。
class ReminderScheduler {
  /// 针对一个已确定的到期时刻 [dueAt] 计算所有提醒触发时刻。
  /// [reminders] 为空 → 返回空（不提醒）。
  List<DateTime> fireTimesForDue(
    DateTime dueAt,
    List<Reminder> reminders,
  ) {
    if (reminders.isEmpty) return const [];
    return reminders.map((r) {
      if (r.isAbsolute) return r.absoluteAt!.toUtc();
      return dueAt.toUtc().add(Duration(minutes: r.offsetMinutes)); // 负偏移=提前
    }).toList();
  }

  /// 对重复任务：取下一个未完成实例的到期时刻进行预排。
  /// 返回 nil 表示暂无可用实例（无限期后或无法展开）。
  DateTime? nextDueForRepeating(Task task, DateTime now, RruleService rrule) {
    if (!task.isRepeating) return task.due?.value;
    final start = task.createdAt;
    return rrule.nextAfter(task.rrule!, now, start: start);
  }
}

