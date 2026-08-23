import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/settings/local_settings.dart';
import 'package:verb_app/core/settings/settings_controller.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/core/storage/backup_service.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/l10n/generated/app_localizations.dart';
import 'package:verb_app/ui/pages/settings_page.dart';

void main() {
  testWidgets('设置页导入 JSON 备份：任务进入目标仓库', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('verb_imp_');
    try {
      // 源仓库造一条任务并导出 JSON 备份
      final srcRepo = InMemoryRepository();
      final svc = TaskService(srcRepo);
      await svc.create(title: '导入过来的任务');

      // 目标仓库（外部持有引用以便断言）
      final destRepo = InMemoryRepository();
      final controller = SettingsController(
        LocalSettings(File('${dir.path}/s.json')),
        destRepo,
      );
      final backupFile = File('${dir.path}/backup.json');
      backupFile.writeAsStringSync(await BackupService(srcRepo).exportJson());

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SettingsPage(
          controller: controller,
          onLocaleChanged: (_) {},
          backupFile: backupFile,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text('导入恢复'));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('已导入'), findsOneWidget);
      final destTasks = await destRepo.allTasks();
      expect(destTasks, hasLength(1));
      expect(destTasks.single.title, '导入过来的任务');
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
