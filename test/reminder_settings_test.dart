import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/notifications/logging_notification_sink.dart';
import 'package:verb_app/core/notifications/reminder_service.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/settings/local_settings.dart';
import 'package:verb_app/core/settings/settings_controller.dart';
import 'package:verb_app/core/storage/file_repository.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';

void main() {
  test('ReminderService: 到期前30分钟安排通知', () async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final due = DateTime.utc(2026, 1, 10, 9, 0).toUtc();
    await svc.create(
      title: '开会',
      due: DueDate(due),
      reminders: const [Reminder(id: 'r1', offsetMinutes: -30)],
    );
    final sink = LoggingNotificationSink();
    final service = ReminderService(tasks: svc, sink: sink);
    await service.syncReminders(now: DateTime.utc(2026, 1, 1));
    expect(sink.scheduled.length, 1);
    expect(sink.scheduled.first.at, DateTime.utc(2026, 1, 10, 8, 30));
  });

  test('无单条提醒时使用全局提前量', () async {
    final repo = InMemoryRepository();
    final tasks = TaskService(repo);
    await tasks.create(
      title: '会议',
      due: DueDate(DateTime.utc(2026, 1, 10, 9)),
    );
    final sink = LoggingNotificationSink();

    await ReminderService(tasks: tasks, sink: sink).syncReminders(
      now: DateTime.utc(2026, 1, 1),
      defaultOffsetMinutes: -30,
    );

    expect(sink.scheduled.single.at, DateTime.utc(2026, 1, 10, 8, 30));
  });

  test('关闭全局默认提醒时没有单条提醒的任务不排程', () async {
    final repo = InMemoryRepository();
    final tasks = TaskService(repo);
    await tasks.create(
      title: '无需提醒',
      due: DueDate(DateTime.utc(2026, 1, 10, 9)),
    );
    final sink = LoggingNotificationSink();

    await ReminderService(tasks: tasks, sink: sink).syncReminders(
      now: DateTime.utc(2026, 1, 1),
      defaultOffsetMinutes: null,
    );

    expect(sink.scheduled, isEmpty);
  });

  test('任务明确关闭提醒时覆盖全局默认', () async {
    final repo = InMemoryRepository();
    final tasks = TaskService(repo);
    await tasks.create(
      title: '明确不提醒',
      due: DueDate(DateTime.utc(2026, 1, 10, 9)),
      reminderPolicy: ReminderPolicy.disabled,
    );
    final sink = LoggingNotificationSink();

    await ReminderService(tasks: tasks, sink: sink).syncReminders(
      now: DateTime.utc(2026, 1, 1),
      defaultOffsetMinutes: -30,
    );

    expect(sink.scheduled, isEmpty);
  });

  test('任务未指定提醒时保持继承默认策略', () async {
    final repo = InMemoryRepository();
    final task = await TaskService(repo).create(
      title: '继承默认',
      due: DueDate(DateTime.utc(2026, 1, 10, 9)),
      reminderPolicy: ReminderPolicy.inherit,
    );
    expect(task.reminders, isEmpty);
    expect(task.reminderPolicy, ReminderPolicy.inherit);
  });

  test('排程 payload 是纯任务 id 而不是显示排程 id', () async {
    final repo = InMemoryRepository();
    final task = await TaskService(repo).create(
      title: '通知定位',
      due: DueDate(DateTime.utc(2026, 1, 10, 9)),
      reminders: const [Reminder(id: 'r', offsetMinutes: -30)],
    );
    final sink = LoggingNotificationSink();

    await ReminderService(tasks: TaskService(repo), sink: sink).syncReminders(
      now: DateTime.utc(2026, 1, 1),
    );

    expect(sink.scheduled.single.payload, task.id);
    expect(sink.scheduled.single.id, isNot(task.id));
  });

  test('English reminder notifications use English body copy', () async {
    final repo = InMemoryRepository();
    final task = await TaskService(repo).create(
      title: 'Meeting',
      due: DueDate(DateTime.utc(2026, 1, 10, 9)),
      reminders: const [Reminder(id: 'r', offsetMinutes: -30)],
    );
    final sink = LoggingNotificationSink();

    await ReminderService(
      tasks: TaskService(repo),
      sink: sink,
      language: 'en',
    ).syncReminders(now: DateTime.utc(2026, 1, 1));

    expect(sink.scheduled.single.body, 'Reminder');
    expect(sink.scheduled.single.payload, task.id);
  });

  test('重排提醒前先取消旧排程并跳过已完成任务', () async {
    final repo = InMemoryRepository();
    final tasks = TaskService(repo);
    await tasks.create(
      title: '已完成',
      status: TaskStatus.done,
      due: DueDate(DateTime.utc(2026, 1, 10, 9)),
      reminders: const [Reminder(id: 'done', offsetMinutes: 0)],
    );
    final sink = LoggingNotificationSink();

    await ReminderService(tasks: tasks, sink: sink).syncReminders(
      now: DateTime.utc(2026, 1, 1),
      defaultOffsetMinutes: 0,
    );

    expect(sink.cancelled, ['*ALL*']);
    expect(sink.scheduled, isEmpty);
  });

  test('重复任务在未来窗口预排多个实例并携带实例 payload', () async {
    final repo = InMemoryRepository();
    final tasks = TaskService(repo);
    await tasks.create(
      title: '每日任务',
      due: DueDate(DateTime.utc(2026, 1, 1, 9)),
      rrule: 'FREQ=DAILY',
      reminders: const [Reminder(id: 'repeat', offsetMinutes: -30)],
    );
    final sink = LoggingNotificationSink();

    await ReminderService(tasks: tasks, sink: sink).syncReminders(
      now: DateTime.utc(2026, 1, 1),
    );

    expect(sink.scheduled.length, greaterThan(1));
    expect(sink.scheduled.every((n) => n.payload!.contains('|')), isTrue);
  });

  test('日期型重复任务在当天上午仍保留当天实例', () async {
    final repo = InMemoryRepository();
    final tasks = TaskService(repo);
    await tasks.create(
      title: '当天记事',
      due: DueDate(DateTime.utc(2026, 1, 1), dateOnly: true),
      rrule: 'FREQ=DAILY',
    );
    final sink = LoggingNotificationSink();

    await ReminderService(tasks: tasks, sink: sink).syncReminders(
      now: DateTime(2026, 1, 1, 8, 30).toUtc(),
      defaultOffsetMinutes: -15,
    );

    expect(sink.scheduled.map((item) => item.at),
        contains(DateTime(2026, 1, 1, 8, 45).toUtc()));
  });

  test('间隔超过预排窗口的重复任务仍排程下一次提醒', () async {
    final repo = InMemoryRepository();
    final tasks = TaskService(repo);
    await tasks.create(
      title: '季度体检',
      due: DueDate(DateTime.utc(2026, 1, 1, 9)),
      rrule: 'FREQ=MONTHLY;INTERVAL=3',
    );
    final sink = LoggingNotificationSink();

    await ReminderService(tasks: tasks, sink: sink).syncReminders(
      now: DateTime.utc(2026, 2, 1),
      defaultOffsetMinutes: -30,
    );

    expect(sink.scheduled.map((item) => item.at),
        contains(DateTime.utc(2026, 4, 1, 8, 30)));
  });

  test('重复任务的单次覆盖使用覆盖后的标题和截止时间排程', () async {
    final repo = InMemoryRepository();
    final tasks = TaskService(repo);
    final first = DateTime.utc(2026, 1, 1, 9);
    final second = DateTime.utc(2026, 1, 2, 9);
    final task = await tasks.create(
      title: '原系列标题',
      due: DueDate(first),
      rrule: 'FREQ=DAILY',
      reminders: const [Reminder(id: 'base', offsetMinutes: -30)],
    );
    await tasks.editRecurring(
      task,
      scope: RecurrenceEditScope.occurrence,
      occurrence: second,
      title: '单次标题',
      due: DueDate(DateTime.utc(2026, 1, 2, 18)),
      reminders: const [Reminder(id: 'override', offsetMinutes: -15)],
      reminderPolicy: ReminderPolicy.enabled,
    );
    final sink = LoggingNotificationSink();

    await ReminderService(tasks: TaskService(repo), sink: sink).syncReminders(
      now: DateTime.utc(2026, 1, 1),
    );

    final occurrenceNotifications = sink.scheduled.where(
      (item) => item.payload == '${task.id}|${occurrenceKey(second)}',
    );
    expect(occurrenceNotifications, hasLength(1));
    expect(occurrenceNotifications.single.title, '单次标题');
    expect(occurrenceNotifications.single.at, DateTime.utc(2026, 1, 2, 17, 45));
  });

  test('SettingsController: 修改持久化 + 备份导出导入', () async {
    final dir = Directory.systemTemp.createTempSync('verb_sc_');
    try {
      final repo = InMemoryRepository();
      await repo.upsertTask(Task(
        id: 'a',
        title: 'A',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ));
      final controller = SettingsController(
        LocalSettings(File('${dir.path}/s.json')),
        repo,
      );
      controller.language = 'en';
      controller.llmBaseUrl = 'https://x/v1';
      controller.llmKey = 'k';
      expect(controller.language, 'en');

      // 导出到文件
      final bf = File('${dir.path}/backup.json');
      await controller.exportTo(bf);
      // 导入到另一个仓库
      final repo2 = FileRepository(File('${dir.path}/d2.json'));
      final c2 =
          SettingsController(LocalSettings(File('${dir.path}/s2.json')), repo2);
      final n = await c2.importFrom(bf);
      expect(n, 1);
      expect((await repo2.allTasks()).single.title, 'A');
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('SettingsController: 主题模式和默认提醒开关可持久化', () async {
    final dir = Directory.systemTemp.createTempSync('verb_theme_');
    try {
      final file = File('${dir.path}/settings.json');
      final controller =
          SettingsController(LocalSettings(file), InMemoryRepository());

      expect(controller.themeMode, ThemeMode.system);
      controller.themeMode = ThemeMode.dark;
      controller.notifyDefaultReminderEnabled = false;
      await controller.flush();

      final reloaded = SettingsController(
        LocalSettings(file),
        InMemoryRepository(),
      );
      expect(reloaded.themeMode, ThemeMode.dark);
      expect(reloaded.defaultReminderOffsetMinutes, isNull);
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
