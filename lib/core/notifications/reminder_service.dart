import '../services/task_service.dart';
import '../models/task.dart';
import '../rrule/rrule_service.dart';
import 'notification_sink.dart';
import 'reminder_scheduler.dart';

/// 把事项提醒换算成通知投递。核心可单测（注入 LoggingNotificationSink）。
class ReminderService {
  final TaskService tasks;
  final NotificationSink sink;
  final RruleService rrule;
  final ReminderScheduler scheduler;
  final String language;
  ReminderService({
    required this.tasks,
    required this.sink,
    RruleService? rrule,
    ReminderScheduler? scheduler,
    this.language = 'zh',
  })  : rrule = rrule ?? RruleService(),
        scheduler = scheduler ?? ReminderScheduler();

  /// 为所有带提醒的任务重建排程（只排未来时刻）。
  /// [defaultOffsetMinutes] 为 null 时关闭没有单条提醒的默认排程。
  Future<void> syncReminders({
    DateTime? now,
    int? defaultOffsetMinutes,
  }) async {
    final t = (now ?? DateTime.now().toUtc()).toUtc();
    await sink.cancelAll();
    final list = await tasks.query(includeDeleted: false);
    for (final task in list) {
      if (task.status == TaskStatus.done) continue;
      final occurrences = task.isRepeating
          ? scheduler.upcomingOccurrencesForRepeating(task, t, rrule)
          : [
              if (task.due != null)
                RecurringOccurrence(
                    occurrence: task.due!.value, dueAt: task.due!.value)
            ];
      for (final item in occurrences) {
        final override = item.override;
        if (override?.status == TaskStatus.done || item.dueAt == null) continue;
        final policy = override?.reminderPolicy ?? task.reminderPolicy;
        if (policy == ReminderPolicy.disabled) continue;
        final reminders = override != null && policy == ReminderPolicy.enabled
            ? override.reminders
            : task.reminders.isNotEmpty
                ? task.reminders
                : defaultOffsetMinutes == null
                    ? const <Reminder>[]
                    : [
                        Reminder(
                          id: 'default',
                          offsetMinutes: defaultOffsetMinutes,
                        )
                      ];
        if (reminders.isEmpty) continue;
        final due = item.dueAt!;
        final dateOnly = override?.due?.dateOnly ?? task.due?.dateOnly ?? false;
        for (final at in scheduler.fireTimesForDue(
          due,
          reminders,
          dateOnly: dateOnly,
        )) {
          if (at.isAfter(t)) {
            final occurrence =
                task.isRepeating ? '|${occurrenceKey(item.occurrence)}' : '';
            await sink.schedule(
              id: _notificationKey(task.id, item.occurrence, reminders, at),
              at: at,
              title: override?.title ?? task.title,
              body: language.toLowerCase().startsWith('en') ? 'Reminder' : '提醒',
              payload: '${task.id}$occurrence',
            );
          }
        }
      }
    }
  }

  String _notificationKey(
    String taskId,
    DateTime occurrence,
    List<Reminder> reminders,
    DateTime at,
  ) {
    final reminderIds = reminders.map((reminder) => reminder.id).join(',');
    return '$taskId|${occurrenceKey(occurrence)}|$reminderIds|${at.toUtc().toIso8601String()}';
  }
}
