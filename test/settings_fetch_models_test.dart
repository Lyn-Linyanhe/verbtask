import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/settings/local_settings.dart';
import 'package:verb_app/core/settings/settings_controller.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/l10n/generated/app_localizations.dart';
import 'package:verb_app/ui/pages/settings_page.dart';

void main() {
  testWidgets('设置页：未填 Base URL / API Key 点“获取模型”给出明确提示', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 用系统临时目录下的文件，避免污染仓库；测试结束删除。
    final dir = Directory.systemTemp.createTempSync('verb_fetch_models_');
    final settingsFile = File('${dir.path}/ux_test_tmp_settings.json');
    addTearDown(() {
      try {
        if (settingsFile.existsSync()) {
          settingsFile.deleteSync();
        }
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    final controller = SettingsController(
      LocalSettings(settingsFile),
      InMemoryRepository(),
    );

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: SettingsPage(controller: controller, onLocaleChanged: (_) {}),
    ));
    await tester.pumpAndSettle();

    // 页面有两处 download_rounded 图标（获取模型按钮 / 导入备份按钮），
    // 树序在先的是模型输入框 suffixIcon 上的“获取模型”按钮，用 .first 定位。
    await tester.tap(find.byIcon(Icons.download_rounded).first);
    // 触发 SnackBar 入场并保持其可见（不用 pumpAndSettle，以免走完 4s 自动消失）。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('请先填写 Base URL 和 API Key，再获取模型'),
      findsOneWidget,
    );
  });
}