import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/ui/pages/board_page.dart';

/// 回归：UX 修复 ① 任务优先级（高/中/低）在列表与看板卡片可见；② 移除冗余的"有期限"标签。
void main() {
  Future<(InMemoryRepository, TaskService)> seed() async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // A：高优先级 + 逾期（应显示"已逾期"与红色旗标）
    await svc.create(
      title: '高优逾期任务',
      due: DueDate(DateTime(today.year, today.month, today.day - 1, 9, 0),
          dateOnly: false),
      priority: 3,
    );
    // B：无优先级、无截止
    await svc.create(title: '普通任务', priority: 0);
    // C：中优先级 + 明天截止（应显示橙色旗标、无冗余"有期限"）
    await svc.create(
      title: '中优明天任务',
      due: DueDate(DateTime(today.year, today.month, today.day + 1, 10, 0),
          dateOnly: false),
      priority: 2,
    );
    return (repo, svc);
  }

  testWidgets('列表：优先级旗标可见 + 冗余"有期限"消失', (tester) async {
    final (repo, _) = await seed();
    await tester.pumpWidget(VerbApp(
        repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    // 高/中优先级任务各有一个旗标（B 无优先级，不显示）
    expect(find.byIcon(Icons.flag_rounded), findsNWidgets(2));
    // 逾期任务（A）仍显示"已逾期"
    expect(find.text('已逾期'), findsOneWidget);
    // 高优先级 tooltip 文案 = 高
    expect(find.byTooltip('高'), findsWidgets);
    // 冗余"有期限"标签已移除
    expect(find.text('有期限'), findsNothing);
  });

  testWidgets('看板：优先级旗标同样显示', (tester) async {
    // 加宽视口，确保末尾的"看板"Tab 可见且可点击
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final (repo, _) = await seed();
    await tester.pumpWidget(VerbApp(
        repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    // 通过"看板"Tab 进入看板页面
    await tester.ensureVisible(find.text('看板').first);
    await tester.tap(find.text('看板').first);
    await tester.pumpAndSettle();

    // 确认真的进入了看板（而非 tap 落空）
    expect(find.byType(BoardPage), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsNWidgets(2),
        reason: '看板卡片上也应显示优先级旗标');
  });
}
