import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';

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
    // C：中优先级 + 明天截止（应显示橙色旗标、无"有期限"）
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

    // 高/中两个任务各有一个优先级旗标
    expect(find.byIcon(Icons.flag_rounded), findsNWidgets(2));
    // 逾期任务显示"已逾期"
    expect(find.text('已逾期'), findsOneWidget);
    // 高优先级 tooltip=高
    expect(find.byTooltip('高'), findsWidgets);
    // 冗余"有期限"应消失
    expect(find.text('有期限'), findsNothing);
  });

  testWidgets('看板：优先级旗标同样显示', (tester) async {
    final (repo, _) = await seed();
    await tester.pumpWidget(VerbApp(
        repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('看板').first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.flag_rounded), findsNWidgets(2),
        reason: '看板卡片上也应显示优先级旗标');
  });
}
