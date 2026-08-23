import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/core/notifications/reminder_scheduler.dart';
import 'package:verb_app/core/settings/local_settings.dart';

void main() {
  test('绝对时刻提醒：返回 absoluteAt（高于偏移）', () {
    final abs = DateTime.utc(2026, 9, 1, 8, 0);
    final s = ReminderScheduler();
    final fires = s.fireTimesForDue(
      DateTime.utc(2026, 9, 1, 10, 0),
      [Reminder(id: 'r1', absoluteAt: abs)],
    );
    expect(fires.single, abs);
  });

  test('相同触发时刻的多个提醒只生成一个通知时刻', () {
    final fires = ReminderScheduler().fireTimesForDue(
      DateTime.utc(2026, 9, 1, 10),
      const [
        Reminder(id: 'r1', offsetMinutes: -30),
        Reminder(id: 'r2', offsetMinutes: -30),
      ],
    );

    expect(fires, [DateTime.utc(2026, 9, 1, 9, 30)]);
  });

  test('仅日期提醒按当天上午九点计算提前量', () {
    final fires = ReminderScheduler().fireTimesForDue(
      DateTime.utc(2026, 9, 1),
      const [Reminder(id: 'date', offsetMinutes: -30)],
      dateOnly: true,
    );

    expect(fires, [DateTime(2026, 9, 1, 8, 30).toUtc()]);
  });

  test('重复任务 seriesId 创建/编辑保持不变', () async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final t = await svc.create(title: '每日锻炼', rrule: 'FREQ=DAILY');
    final edited = await svc.edit(t, title: '每日锻炼 v2');
    expect(edited.title, '每日锻炼 v2');
    expect(edited.rrule, 'FREQ=DAILY');
    expect(t.seriesId, isNotEmpty);
    expect(edited.seriesId, t.seriesId);
    expect(t.id, edited.id);
  });

  test('重复任务完成或跳过单个实例不会完成整个系列', () async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final task = await svc.create(
      title: '每日锻炼',
      due: DueDate(DateTime.utc(2026, 1, 1, 9)),
      rrule: 'FREQ=DAILY',
    );
    final first = DateTime.utc(2026, 1, 1, 9);
    final completed = await svc.completeOccurrence(
      task,
      first,
      completed: true,
    );
    expect(completed.status, TaskStatus.todo);
    expect(completed.completedOccurrences, contains(occurrenceKey(first)));

    final skipped = await svc.skipOccurrence(
      completed,
      first.add(const Duration(days: 1)),
    );
    expect(skipped.status, TaskStatus.todo);
    expect(skipped.skippedOccurrences,
        contains(occurrenceKey(first.add(const Duration(days: 1)))));
  });

  test('search 过滤命中 title 或 notes', () async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    await svc.create(title: '买菜', notes: '记得带购物袋');
    await svc.create(title: '交房租');
    final r1 = await svc.query(search: '购物袋');
    expect(r1.map((t) => t.title), ['买菜']);
    final r2 = await svc.query(search: '房租');
    expect(r2.map((t) => t.title), ['交房租']);
  });

  test('LocalSettings：托盘/置顶/自启/同步间隔/模型 默认值与持久化', () async {
    final dir = await Directory.systemTemp.createTemp('verbset');
    addTearDown(() => dir.delete(recursive: true));
    final f = File('${dir.path}/settings.json');
    final s = LocalSettings(f);
    // 默认值
    expect(s.trayEnabled, isTrue);
    expect(s.alwaysOnTop, isFalse);
    expect(s.autostartEnabled, isTrue);
    expect(s.syncAutoIntervalMin, 30);
    expect(s.llmModel, '');
    // 写入并持久化
    s.alwaysOnTop = true;
    s.syncAutoIntervalMin = 15;
    s.llmModel = 'deepseek-chat';
    await s.save();
    final s2 = LocalSettings(f);
    expect(s2.alwaysOnTop, isTrue);
    expect(s2.syncAutoIntervalMin, 15);
    expect(s2.llmModel, 'deepseek-chat');
  });
}
