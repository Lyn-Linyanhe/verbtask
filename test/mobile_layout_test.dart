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
import 'package:verb_app/ui/pages/list_manage_page.dart';

void main() {
  testWidgets('首页在窄屏和大字号下无溢出', (tester) async {
    final repo = InMemoryRepository();
    final service = TaskService(repo);
    await service.create(
      title: '这是一条需要在手机窄屏中完整适配的任务',
      due: DueDate(DateTime.now().toUtc().add(const Duration(days: 1))),
      priority: 3,
    );
    final dir = Directory.systemTemp.createTempSync('verb_mobile_layout_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final settings = SettingsController(
      LocalSettings(File('${dir.path}/settings.json')),
      repo,
    );

    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final height in [800.0, 300.0]) {
          tester.view.physicalSize = Size(width, height);
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pumpWidget(VerbApp(
            repository: repo,
            settings: settings,
            initialLocale: const Locale('zh'),
          ));
          await tester.pumpAndSettle();
          final error = tester.takeException();
          expect(error, isNull,
              reason: 'width=$width height=$height textScale=$scale');
        }
      }
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  testWidgets('清单命名弹窗在短屏下可滚动，不发生布局溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final service = TaskService(InMemoryRepository());

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: ListManagePage(service: service),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.playlist_add_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页完成控件保留 48dp 触控热区', (tester) async {
    final repo = InMemoryRepository();
    final task = await TaskService(repo).create(title: '触控热区');
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(VerbApp(
      repository: repo,
      initialLocale: const Locale('zh'),
    ));
    await tester.pumpAndSettle();

    final toggle = find.byKey(ValueKey('task-toggle-${task.id}'));
    expect(toggle, findsOneWidget);
    expect(tester.getSize(toggle).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
  });
}
