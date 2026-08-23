import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/app/navigation.dart';
import 'package:verb_app/app/open_task.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/ui/pages/task_edit_page.dart';

/// 回归：通知点击后按任务 id 打开对应编辑页。
void main() {
  testWidgets('openTaskById：能找到任务并打开编辑页', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final task = await svc.create(title: '通知目标任务');
    var changed = 0;

    await tester.pumpWidget(
        VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    final ok = await openTaskById(
      repo,
      task.id,
      navigatorKey: appNavigatorKey,
      onChanged: () async => changed++,
    );
    await tester.pumpAndSettle();

    expect(ok, isTrue);
    expect(find.byType(TaskEditPage), findsOneWidget);
    // 标题应回显
    expect(find.text('通知目标任务'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, '通知目标任务（已更新）');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(changed, 1);
  });

  testWidgets('openTaskById：找不到任务则不导航', (tester) async {
    final repo = InMemoryRepository();
    await tester.pumpWidget(
        VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    final ok =
        await openTaskById(repo, 'no-such-id', navigatorKey: appNavigatorKey);
    await tester.pumpAndSettle();
    expect(ok, isFalse);
    expect(find.byType(TaskEditPage), findsNothing);
  });

  testWidgets('openTaskById：兼容旧版带时间后缀的通知 payload', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final task = await svc.create(title: '旧通知目标');

    await tester.pumpWidget(
        VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    final ok = await openTaskById(
      repo,
      '${task.id}-1760000000000',
      navigatorKey: appNavigatorKey,
    );
    await tester.pumpAndSettle();

    expect(ok, isTrue);
    expect(find.byType(TaskEditPage), findsOneWidget);
  });

  testWidgets('openTaskById：重复任务 payload 保留 occurrence 上下文', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final first = DateTime.utc(2026, 1, 1, 9);
    final occurrence = DateTime.utc(2026, 1, 2, 9);
    final task = await svc.create(
      title: '原系列标题',
      due: DueDate(first),
      rrule: 'FREQ=DAILY',
    );
    await svc.editRecurring(
      task,
      scope: RecurrenceEditScope.occurrence,
      occurrence: occurrence,
      title: '通知实例标题',
      due: DueDate(DateTime.utc(2026, 1, 2, 18)),
    );

    await tester.pumpWidget(
        VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    final ok = await openTaskById(
      repo,
      '${task.id}|${occurrenceKey(occurrence)}',
      navigatorKey: appNavigatorKey,
    );
    await tester.pumpAndSettle();

    expect(ok, isTrue);
    expect(find.text('通知实例标题'), findsWidgets);
  });

  testWidgets('导航尚未建立时暂存通知点击并在首帧后打开', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final task = await svc.create(title: '冷启动通知目标');
    final coldStartKey = GlobalKey<NavigatorState>();

    final queued = await openTaskById(
      repo,
      task.id,
      navigatorKey: coldStartKey,
    );
    expect(queued, isFalse);

    await tester.pumpWidget(
        VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    final opened = await flushPendingTaskOpen(
      repo,
      navigatorKey: appNavigatorKey,
    );
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(find.byType(TaskEditPage), findsOneWidget);
    expect(find.text('冷启动通知目标'), findsWidgets);
  });
}
