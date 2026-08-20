import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/l10n/generated/app_localizations.dart';
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
}
