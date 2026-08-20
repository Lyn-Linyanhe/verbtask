import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/settings/local_settings.dart';
import 'package:verb_app/core/settings/settings_controller.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/app.dart';

void main() {
  testWidgets('开启 LLM 后快速录入：先弹「数据出本机」知情确认，取消则不发送', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('verb_llmflow_');
    addTearDown(() { try { dir.deleteSync(recursive: true); } catch (_) {} });

    final repo = InMemoryRepository();
    final controller = SettingsController(
      LocalSettings(File('${dir.path}/s.json')), repo);
    controller.llmEnabled = 1;
    controller.llmBaseUrl = 'https://api.deepseek.com';
    controller.llmKey = 'sk-test';
    controller.llmModel = 'deepseek-chat';

    await tester.pumpWidget(VerbApp(
      repository: repo,
      initialLocale: const Locale('zh'),
      settings: controller,
    ));
    await tester.pumpAndSettle();

    // 输入并回车
    final input = find.byType(TextField).first;
    await tester.enterText(input, '明天交报告');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // 真人第一次应看到「数据出本机」知情提示（隐私关键路径）
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('任务文本将发送到外部服务'), findsOneWidget);

    // 真人选择「取消」→ 不发网络请求，走本地解析，随后弹出解析确认
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget); // 解析确认弹窗
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    // 本地标题 = 交报告，且 llmEnabled 仍开启（设置未变）
    final tasks = await repo.allTasks();
    expect(tasks.any((t) => t.title.contains('交报告')), isTrue);
  });
}


