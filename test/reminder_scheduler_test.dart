import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/notifications/reminder_scheduler.dart';
import 'package:verb_app/core/rrule/rrule_service.dart';

void main() {
  test('重复任务从截止时间而不是创建时间展开', () {
    final task = Task(
      id: 'repeat',
      title: '打卡',
      rrule: 'FREQ=DAILY',
      due: DueDate(DateTime.utc(2026, 1, 10, 9)),
      createdAt: DateTime.utc(2025, 1, 1),
      updatedAt: DateTime.utc(2025, 1, 1),
    );

    final next = ReminderScheduler().nextDueForRepeating(
      task,
      DateTime.utc(2026, 1, 10, 10),
      RruleService(),
    );

    expect(next, DateTime.utc(2026, 1, 11, 9));
  });

  test('没有截止时间的重复任务没有可排程实例', () {
    final task = Task(
      id: 'repeat',
      title: '无起点',
      rrule: 'FREQ=DAILY',
      createdAt: DateTime.utc(2025, 1, 1),
      updatedAt: DateTime.utc(2025, 1, 1),
    );

    expect(
      ReminderScheduler().nextDueForRepeating(
        task,
        DateTime.utc(2026, 1, 10),
        RruleService(),
      ),
      isNull,
    );
  });
}
