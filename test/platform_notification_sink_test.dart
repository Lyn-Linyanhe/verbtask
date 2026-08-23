import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/notifications/app_notifications.dart';
import 'package:verb_app/core/notifications/platform_notification_sink.dart';

void main() {
  final now = DateTime.utc(2026, 8, 23, 10);

  test('任务提醒同时提供 Android 和 Windows 的平台详情', () {
    final details = taskReminderNotificationDetails;

    expect(details.android, isNotNull);
    expect(details.windows, isNotNull);
    expect(
      details.windows!.duration,
      WindowsNotificationDuration.long,
    );
  });

  test('Android 有精确闹钟权限时使用精确排程，否则显式降级', () {
    expect(
      androidReminderScheduleMode(exactAlarmsAvailable: true),
      AndroidScheduleMode.exactAllowWhileIdle,
    );
    expect(
      androidReminderScheduleMode(exactAlarmsAvailable: false),
      AndroidScheduleMode.inexactAllowWhileIdle,
    );
  });

  test('English notification details do not contain Chinese channel copy', () {
    final details = taskReminderNotificationDetailsFor('en');
    final android = details.android!;

    expect(android.channelName, 'VerbTask reminders');
    expect(android.channelDescription, 'Task due and advance reminders');
  });

  test('only asks for exact alarms when an active task can be scheduled', () {
    final task = Task(
      id: 'task-1',
      title: '记事',
      due: DueDate(now.add(const Duration(hours: 2))),
      createdAt: now,
      updatedAt: now,
    );

    expect(
      shouldRequestExactAlarms([task], defaultOffsetMinutes: null),
      isFalse,
    );
    expect(
      shouldRequestExactAlarms([task], defaultOffsetMinutes: -30),
      isTrue,
    );
    expect(
      shouldRequestExactAlarms(
        [
          task.copyWith(
            reminders: const [Reminder(id: 'r1', offsetMinutes: -10)],
          ),
        ],
        defaultOffsetMinutes: null,
      ),
      isTrue,
    );
  });
}
