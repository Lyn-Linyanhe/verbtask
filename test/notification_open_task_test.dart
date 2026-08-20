import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/app/navigation.dart';
import 'package:verb_app/app/open_task.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/ui/pages/task_edit_page.dart';

/// 回归：通知点击后按任务 id 打开对应编辑页。
void main() {
  testWidgets('openTaskById：能找到任务并打开编辑页', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final task = await svc.create(title: '通知目标任务');

    await tester.pumpWidget(VerbApp(
        repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    final ok = await openTaskById(repo, task.id, navigatorKey: appNavigatorKey);
    await tester.pumpAndSettle();

    expect(ok, isTrue);
    expect(find.byType(TaskEditPage), findsOneWidget);
    // 标题应回显
    expect(find.text('通知目标任务'), findsWidgets);
  });

  testWidgets('openTaskById：找不到任务则不导航', (tester) async {
    final repo = InMemoryRepository();
    await tester.pumpWidget(VerbApp(
        repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    final ok = await openTaskById(repo, 'no-such-id', navigatorKey: appNavigatorKey);
    await tester.pumpAndSettle();
    expect(ok, isFalse);
    expect(find.byType(TaskEditPage), findsNothing);
  });
}
