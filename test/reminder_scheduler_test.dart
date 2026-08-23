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

  test('重复任务预排未来窗口且跳过已完成实例', () {
    final task = Task(
      id: 'repeat',
      title: '每日打卡',
      rrule: 'FREQ=DAILY',
      due: DueDate(DateTime.utc(2026, 1, 1, 9)),
      completedOccurrences: {
        occurrenceKey(DateTime.utc(2026, 1, 2, 9)),
      },
      createdAt: DateTime.utc(2025, 1, 1),
      updatedAt: DateTime.utc(2025, 1, 1),
    );
    final upcoming = ReminderScheduler().upcomingDueForRepeating(
      task,
      DateTime.utc(2026, 1, 1),
      RruleService(),
      window: const Duration(days: 4),
    );

    expect(upcoming, contains(DateTime.utc(2026, 1, 1, 9)));
    expect(upcoming, isNot(contains(DateTime.utc(2026, 1, 2, 9))));
    expect(upcoming.length, 3);
  });

  test('COUNT 和 UNTIL 限制实例展开', () {
    final rrule = RruleService();
    expect(
      rrule
          .instancesBetween(
            'FREQ=DAILY;COUNT=3',
            DateTime.utc(2026, 1, 1),
            DateTime.utc(2026, 1, 10),
            start: DateTime.utc(2026, 1, 1),
          )
          .length,
      3,
    );
    expect(
      rrule.instancesBetween(
        'FREQ=DAILY;UNTIL=20260103T000000Z',
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 1, 10),
        start: DateTime.utc(2026, 1, 1),
      ),
      [
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 1, 2),
        DateTime.utc(2026, 1, 3),
      ],
    );
  });
}
