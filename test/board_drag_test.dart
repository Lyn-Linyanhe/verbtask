import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/ui/pages/board_page.dart';

/// 回归：UUIX 能力升级——看板拖拽移动任务（把任务从"未开始"拖到"已完成"）。
void main() {
  testWidgets('看板拖拽：任务从未开始拖到已完成', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    await svc.create(title: '待拖拽任务'); // todo
    await svc.create(title: '另一个任务', status: TaskStatus.doing);
    await svc.create(title: '已完成示例', status: TaskStatus.done);

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

    // 从未开始列(左侧)向右拖到"已完成"列（右数第三列中心约 x=720）
    await tester.timedDrag(
      find.text('待拖拽任务'),
      const Offset(640, 0),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();

    final tasks = await repo.allTasks();
    final moved = tasks.singleWhere((t) => t.title == '待拖拽任务');
    expect(moved.status, TaskStatus.done, reason: '拖拽后应移动到已完成列');
  });
}
