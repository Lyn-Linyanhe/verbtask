import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/ui/pages/board_page.dart';

/// 回归：UX 第二波 ③ 看板日期格式与首页统一（X月X日 HH:mm，非 M/d）。
void main() {
  testWidgets('看板显示中文日期格式', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 15, 0);
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    await svc.create(
        title: '带日期的看板任务', due: DueDate(tomorrow, dateOnly: false));

    await tester.pumpWidget(
        VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    final boardTab = find.byKey(const ValueKey('view-board'));
    await tester.ensureVisible(boardTab);
    expect(boardTab, findsOneWidget);
    expect(boardTab.hitTestable(), findsOneWidget);
    await tester.tap(boardTab);
    await tester.pumpAndSettle();
    expect(find.byType(BoardPage), findsOneWidget);

    // 中文"X月":如 8月
    expect(find.textContaining('月'), findsWidgets);
    // 时刻仍在
    expect(find.textContaining('15:00'), findsOneWidget);
    // 不应再出现 M/d 英文格式直接被整段拼接（宽松：不应存在 "月" 前的裸斜杠格式）
    expect(find.textContaining('8/2'), findsNothing);
  });
}
