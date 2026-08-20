import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/l10n/generated/app_localizations.dart';
import 'package:verb_app/ui/pages/recycle_bin_page.dart';

// 中文 localization 外壳（与 test/user_flow_test.dart 的 localizedApp 一致）
Widget localizedApp(Widget home) {
  return MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: const [Locale('en'), Locale('zh')],
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

void main() {
  testWidgets('回收站删除：点删除图标弹出确认弹窗（标题存在）', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final t = await svc.create(title: '确认弹窗用例');
    await svc.recycle(t);

    await tester.pumpWidget(localizedApp(RecycleBinPage(service: svc)));
    await tester.pumpAndSettle();

    expect(find.text('确认弹窗用例'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_forever_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('确认彻底删除'), findsOneWidget);
    expect(find.text('删除后无法恢复，确定要继续吗？'), findsOneWidget);
  });

  testWidgets('回收站删除：点取消则任务保留在回收站', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final t = await svc.create(title: '取消保留用例');
    await svc.recycle(t);

    await tester.pumpWidget(localizedApp(RecycleBinPage(service: svc)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_forever_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    // 弹窗关闭，任务仍在回收站（仍 deleted 状态）
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('取消保留用例'), findsOneWidget);
    final afterCancel = await repo.allTasks();
    expect(afterCancel, hasLength(1));
    expect(afterCancel.single.deleted, isTrue);
  });

  testWidgets('回收站删除：点彻底删除则物理删除', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final t = await svc.create(title: '确认删除用例');
    await svc.recycle(t);

    await tester.pumpWidget(localizedApp(RecycleBinPage(service: svc)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_forever_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '彻底删除'));
    await tester.pumpAndSettle();

    // 物理删除：任务从任务列表中消失
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('确认删除用例'), findsNothing);
    expect((await repo.allTasks()).isEmpty, isTrue);
  });
}
