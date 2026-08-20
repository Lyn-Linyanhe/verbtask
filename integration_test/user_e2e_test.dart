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
    await tester.pumpWidget(VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    // 1) 快速添加中文自然语言任务
    await addTask(tester, '明天下午3点 交周报 高');
    var tasks = await repo.allTasks();
    expect(tasks.any((t) => t.title.contains('交周报')), isTrue, reason: '任务入库且周字保留');
    expect(tasks.any((t) => t.due?.value.toLocal().hour == 15), isTrue, reason: '截止解析为下午3点');

    // 2) 再添加
    await addTask(tester, '买菜');

    // 3) 搜索
    final search = find.byType(TextField).at(1);
    await tester.enterText(search, '交周报');
    await tester.pumpAndSettle();
    expect(find.textContaining('交周报'), findsWidgets);
    expect(find.text('买菜'), findsNothing);
    await tester.enterText(search, '');
    await tester.pumpAndSettle();

    // 4) 创建清单
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

    // 5) 编辑任务状态
    await tester.tap(find.textContaining('交周报').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('进行中').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final edited = (await repo.allTasks()).firstWhere((t) => t.title.contains('交周报'));
    expect(edited.status, TaskStatus.doing);

    // 6) 看板
    await tester.tap(find.byKey(const ValueKey('view-board')));
    await tester.pumpAndSettle();
    expect(find.text('未开始'), findsOneWidget);
    expect(find.text('进行中'), findsOneWidget);
    await goBack(tester);

    // 7) 回收站
    tasks = await repo.allTasks();
    final buy = tasks.firstWhere((t) => t.title.contains('买菜'));
    await svc.recycle(buy);
    await tester.pumpWidget(VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('买菜'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.restore_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('买菜'), findsNothing);
    await goBack(tester);

    // 8) 设置页
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('LLM 增强解析'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('同步与提醒'), findsOneWidget);
  });
}
