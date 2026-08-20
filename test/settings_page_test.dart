import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/settings/local_settings.dart';
import 'package:verb_app/core/settings/settings_controller.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/l10n/generated/app_localizations.dart';
import 'package:verb_app/ui/pages/settings_page.dart';

void main() {
  testWidgets('设置页切换语言回调 + 导出备份', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('verb_setp_');
    Locale? changed;
    try {
      final controller = SettingsController(
        LocalSettings(File('${dir.path}/s.json')),
        InMemoryRepository(),
      );
      final backupFile = File('${dir.path}/backup.json');
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SettingsPage(
          controller: controller,
          onLocaleChanged: (l) => changed = l,
          backupFile: backupFile,
          onQuickSync: null,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(changed, const Locale('en'));
      expect(controller.language, 'en');

      await tester.runAsync(() async {
        await tester.tap(find.text('导出备份'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(backupFile.existsSync(), isTrue);
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('设置页导出 CSV 备份', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('verb_setcsv_');
    try {
      final controller = SettingsController(
        LocalSettings(File('${dir.path}/s.json')),
        InMemoryRepository(),
      );
      final csvFile = File('${dir.path}/backup.csv');
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SettingsPage(
          controller: controller,
          onLocaleChanged: (_) {},
          csvFile: csvFile,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text('导出 CSV'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(csvFile.existsSync(), isTrue);
      expect(csvFile.readAsStringSync(), contains('id,title,notes,listId'));
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
