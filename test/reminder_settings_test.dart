import 'dart:io';
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

  test('SettingsController: 修改持久化 + 备份导出导入', () async {
    final dir = Directory.systemTemp.createTempSync('verb_sc_');
    try {
      final repo = InMemoryRepository();
      await repo.upsertTask(Task(
        id: 'a', title: 'A',
        createdAt: DateTime.utc(2026,1,1), updatedAt: DateTime.utc(2026,1,1),
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
      final c2 = SettingsController(LocalSettings(File('${dir.path}/s2.json')), repo2);
      final n = await c2.importFrom(bf);
      expect(n, 1);
      expect((await repo2.allTasks()).single.title, 'A');
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
