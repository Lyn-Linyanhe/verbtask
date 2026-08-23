import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> goBack(WidgetTester tester) async {
    await tester.pumpAndSettle();
    final b = find.byType(BackButton);
    if (b.evaluate().isNotEmpty) {
      await tester.tap(b);
    } else {
      await tester.pageBack();
    }
    await tester.pumpAndSettle();
  }

  Future<void> addTask(WidgetTester tester, String text) async {
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(FilledButton).evaluate().isNotEmpty) break;
    }
    await tester.pumpAndSettle();
    final btn = find.widgetWithText(FilledButton, '确认').evaluate().isNotEmpty
        ? find.widgetWithText(FilledButton, '确认')
        : (find.widgetWithText(FilledButton, 'Confirm').evaluate().isNotEmpty
            ? find.widgetWithText(FilledButton, 'Confirm')
            : find.byType(FilledButton).last);
    await tester.tap(btn);
    await tester.pumpAndSettle();
  }

  testWidgets('E2E 全流程（真实桌面引擎）', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    await tester.pumpWidget(
        VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    await addTask(tester, '明天下午3点 交周报 高');
    var tasks = await repo.allTasks();
    expect(tasks.any((t) => t.title.contains('交周报')), isTrue);
    expect(tasks.any((t) => t.due?.value.toLocal().hour == 15), isTrue);

    await addTask(tester, '买菜');

    final search = find.byType(TextField).at(1);
    await tester.enterText(search, '交周报');
    await tester.pumpAndSettle();
    expect(find.textContaining('交周报'), findsWidgets);
    expect(find.text('买菜'), findsNothing);
    await tester.enterText(search, '');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理清单'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.playlist_add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '工作');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect((await svc.allLists()).any((l) => l.name == '工作'), isTrue);
    await goBack(tester);

    await tester.tap(find.textContaining('交周报').first);
    await tester.pumpAndSettle();
    final statusField = find.byKey(const ValueKey('task-status'));
    await tester.ensureVisible(statusField);
    await tester.tap(statusField);
    await tester.pumpAndSettle();
    final doingOption = find.text('进行中').last;
    await tester.ensureVisible(doingOption);
    await tester.tap(doingOption);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final edited =
        (await repo.allTasks()).firstWhere((t) => t.title.contains('交周报'));
    expect(edited.status, TaskStatus.doing);

    await tester.tap(find.byKey(const ValueKey('view-board')));
    await tester.pumpAndSettle();
    expect(find.text('未开始'), findsOneWidget);
    expect(find.text('进行中'), findsOneWidget);
    await goBack(tester);

    tasks = await repo.allTasks();
    final buy = tasks.firstWhere((t) => t.title.contains('买菜'));
    await svc.recycle(buy);
    await tester.pumpWidget(
        VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('买菜'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.restore_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('买菜'), findsNothing);
    await goBack(tester);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('LLM 增强解析'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('同步与提醒'), findsOneWidget);
    await goBack(tester);
  });

  testWidgets('E2E 悬浮速记 + 设置内交互（主题/语言/LLM）', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = InMemoryRepository();
    await tester.pumpWidget(
        VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    // 悬浮速记
    final noteBtn = find.byIcon(Icons.sticky_note_2_outlined);
    expect(noteBtn, findsOneWidget);
    await tester.tap(noteBtn);
    await tester.pumpAndSettle();
    final noteField = find.byType(TextField);
    expect(noteField, findsOneWidget, reason: '速记输入框');
    await tester.enterText(noteField, '速记一条');
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(FilledButton).evaluate().isNotEmpty) break;
    }
    await tester.pumpAndSettle();
    final btn = find.widgetWithText(FilledButton, '确认').evaluate().isNotEmpty
        ? find.widgetWithText(FilledButton, '确认')
        : find.byType(FilledButton).last;
    await tester.tap(btn);
    await tester.pumpAndSettle();
    var tasks = await repo.allTasks();
    expect(tasks.any((t) => t.title.contains('速记一条')), isTrue);
    await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);

    // 设置：主题 / 语言 / LLM
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('语言'), findsOneWidget);

    // 主题切换：点击「深色」segment
    await tester.ensureVisible(find.text('深色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    // 诊断：语言下拉打开前后的可见 Text
    final dd = find.byType(DropdownButtonFormField<String>);
    expect(dd, findsOneWidget, reason: '语言下拉应存在');
    await tester.tap(dd);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    // 若已出现 English 则选择
    if (find.text('English').evaluate().isNotEmpty) {
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
    }
    expect(find.text('Settings'), findsOneWidget, reason: '语言切换后应为英文设置标题');

    // LLM 字段（当前为英文界面）
    await tester.ensureVisible(find.text('LLM-enhanced parsing'));
    await tester.pumpAndSettle();
    expect(find.text('Base URL (OpenAI-compatible)'), findsOneWidget);
    expect(find.text('API key (stored locally)'), findsOneWidget);
    await goBack(tester);
  });
}
