import '../services/task_service.dart';
import '../rrule/rrule_service.dart';
import 'notification_sink.dart';
import 'reminder_scheduler.dart';

/// 把任务提醒换算成通知投递。核心可单测（注入 LoggingNotificationSink）。
class ReminderService {
  final TaskService tasks;
  final NotificationSink sink;
  final RruleService rrule;
  final ReminderScheduler scheduler;
  ReminderService({
    required this.tasks,
    required this.sink,
    RruleService? rrule,
    ReminderScheduler? scheduler,
  })  : rrule = rrule ?? RruleService(),
        scheduler = scheduler ?? ReminderScheduler();

  /// 为所有带提醒的任务重建排程（只排未来时刻）。
  Future<void> syncReminders({DateTime? now}) async {
    final t = (now ?? DateTime.now().toUtc()).toUtc();
    final list = await tasks.query(includeDeleted: false);
    for (final task in list) {
      if (task.reminders.isEmpty) continue;
      final due = task.isRepeating
          ? scheduler.nextDueForRepeating(task, t, rrule)
          : task.due?.value;
      if (due == null) continue;
      for (final at in scheduler.fireTimesForDue(due, task.reminders)) {
        if (at.isAfter(t)) {
          await sink.schedule(
            id: '${task.id}-${at.millisecondsSinceEpoch}',
            at: at,
            title: task.title,
            body: '任务提醒',
          );
        }
      }
    }
  }
}
