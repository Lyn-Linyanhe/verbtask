import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/l10n/generated/app_localizations.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/ui/pages/board_page.dart';
import 'package:verb_app/ui/pages/list_manage_page.dart';
import 'package:verb_app/ui/pages/task_edit_page.dart';
import 'package:verb_app/ui/pages/recycle_bin_page.dart';

Widget localizedApp(Widget home, {Locale locale = const Locale('zh')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('zh')],
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

void main() {
  testWidgets('编辑页修改标题后保存', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final t = await svc.create(title: '旧标题');
    await tester.pumpWidget(localizedApp(TaskEditPage(task: t, service: svc)));

    await tester.enterText(find.byType(TextField).first, '新标题');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final updated = (await repo.allTasks()).single;
    expect(updated.title, '新标题');
  });

  testWidgets('回收站：恢复后从回收站移除', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final t = await svc.create(title: '待删');
    final recycled = await svc.recycle(t);
    expect(recycled.deleted, isTrue);

    await tester.pumpWidget(localizedApp(RecycleBinPage(service: svc)));
    await tester.pumpAndSettle();
    expect(find.text('待删'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.restore_rounded));
    await tester.pumpAndSettle();
    expect(find.text('待删'), findsNothing);

    final all = await repo.allTasks();
    expect(all.single.deleted, isFalse);
  });

  testWidgets('英文编辑页和回收站不泄漏中文页面文案', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final task = await svc.create(title: 'Task');
    final deleted = await svc.recycle(task);
    await tester.pumpWidget(localizedApp(
      TaskEditPage(task: deleted, service: svc),
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsOneWidget);
    expect(find.text('编辑任务'), findsNothing);

    await tester.pumpWidget(localizedApp(
      RecycleBinPage(service: svc),
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Recycle bin'), findsOneWidget);
    expect(find.text('回收站'), findsNothing);
  });

  testWidgets('清单管理页可以创建清单', (tester) async {
    final service = TaskService(InMemoryRepository());
    await tester.pumpWidget(localizedApp(ListManagePage(service: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.playlist_add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '工作');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('工作'), findsOneWidget);
    expect((await service.allLists()).single.name, '工作');
  });

  testWidgets('看板显示三种状态列', (tester) async {
    final service = TaskService(InMemoryRepository());
    await service.create(title: '待做', status: TaskStatus.todo);
    await service.create(title: '处理中任务', status: TaskStatus.doing);
    await service.create(title: '完成', status: TaskStatus.done);

    await tester.pumpWidget(localizedApp(BoardPage(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('未开始'), findsOneWidget);
    expect(find.text('进行中'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('待做'), findsOneWidget);
  });

  testWidgets('搜索使用独立输入框，不打开自然语言确认弹窗', (tester) async {
    final repo = InMemoryRepository();
    final service = TaskService(repo);
    await service.create(title: '搜索目标');
    await tester.pumpWidget(VerbApp(
      repository: repo,
      initialLocale: const Locale('zh'),
    ));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(1), '搜索目标');
    await tester.pumpAndSettle();

    expect(find.text('搜索目标'), findsAtLeastNWidgets(1));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('确认'), findsNothing);
  });

  testWidgets('首页可切换到清单视图并显示清单任务', (tester) async {
    final repo = InMemoryRepository();
    final service = TaskService(repo);
    final list = await service.createList(name: '工作');
    await service.create(title: '工作任务', listId: list.id);

    await tester.pumpWidget(VerbApp(
      repository: repo,
      initialLocale: const Locale('zh'),
    ));
    await tester.pumpAndSettle();
    await tester.fling(
        find.byKey(const ValueKey('view-tabs')), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('view-list')));
    await tester.pumpAndSettle();

    expect(find.text('工作'), findsOneWidget);
    expect(find.text('工作任务'), findsOneWidget);
  });
}
