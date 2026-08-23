import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/settings/local_settings.dart';
import 'package:verb_app/core/settings/settings_controller.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/l10n/generated/app_localizations.dart';
import 'package:verb_app/ui/pages/task_edit_page.dart';

void main() {
  testWidgets('VerbApp uses the persisted language when it starts',
      (tester) async {
    final settingsFile = File('verb_locale_test_settings.json');
    settingsFile.writeAsStringSync('{"language":"en"}');
    addTearDown(() {
      if (settingsFile.existsSync()) settingsFile.deleteSync();
    });
    final repo = InMemoryRepository();
    final settings = SettingsController(
      LocalSettings(settingsFile),
      repo,
    );

    await tester.pumpWidget(VerbApp(repository: repo, settings: settings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.locale, const Locale('en'));
  });

  testWidgets('empty task title shows an error and keeps the edit page open',
      (tester) async {
    final repo = InMemoryRepository();
    final service = TaskService(repo);
    final task = await service.create(title: '原标题');

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: TaskEditPage(task: task, service: service),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pump();

    expect(find.byType(TaskEditPage), findsOneWidget);
    expect(find.text('标题不能为空'), findsOneWidget);
  });

  testWidgets('inherited reminder policy is shown as using the default',
      (tester) async {
    final repo = InMemoryRepository();
    final service = TaskService(repo);
    final task = await service.create(
      title: '继承提醒',
      due: DueDate(DateTime.utc(2026, 1, 10, 9)),
      reminderPolicy: ReminderPolicy.inherit,
    );

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: TaskEditPage(task: task, service: service),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('使用默认提醒'), findsOneWidget);
  });
}
