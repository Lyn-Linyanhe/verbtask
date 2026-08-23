import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';

/// 回归：UX 第二波 ① "进行中"状态显式徽章 ② 录入/搜索两输入框易辨。
void main() {
  testWidgets('进行中任务显示徽章，未开始/已完成不显示', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    await svc.create(title: '正在写的报告', status: TaskStatus.doing);
    await svc.create(title: '没动的任务');
    await svc.create(title: '已完成任务', status: TaskStatus.done);

    await tester.pumpWidget(
        VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('doing-badge')), findsOneWidget,
        reason: '仅"进行中"任务应显示徽章');
    // 徽章文本为"进行中"
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('doing-badge')),
          matching: find.text('进行中'),
        ),
        findsOneWidget);
  });

  testWidgets('录入框与搜索框 hint 可区分', (tester) async {
    final repo = InMemoryRepository();
    await tester.pumpWidget(
        VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    final addField = tester.widget<TextField>(find.byType(TextField).first);
    final searchField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(addField.decoration?.hintText, '记下一件事…');
    expect(searchField.decoration?.hintText, '搜索事项');
    expect(
        addField.decoration?.hintText, isNot(searchField.decoration?.hintText));
  });
}
