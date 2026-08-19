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
