import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/l10n/generated/app_localizations.dart';
import 'package:verb_app/ui/pages/task_edit_page.dart';

/// 回归：UX 修复 ② 编辑页「保存」按钮固定底部、小视口下无需滚动即可见可点。
void main() {
  testWidgets('编辑页：小视口下保存按钮无需滚动即可见可点', (tester) async {
    tester.view.physicalSize = const Size(520, 380);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final t = await svc.create(title: '编辑保存回归');

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: TaskEditPage(task: t, service: svc),
    ));
    await tester.pumpAndSettle();

    final saveFinder = find.widgetWithText(FilledButton, '保存');
    expect(saveFinder, findsOneWidget);
    expect(saveFinder.hitTestable(), findsOneWidget,
        reason: '保存按钮应固定在底部，无需滚动即可点击');
  });

  testWidgets('编辑页：保存仍能提交修改并回到宿主', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final t = await svc.create(title: '旧标题');

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              child: const Text('打开编辑页'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => TaskEditPage(task: t, service: svc)),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('打开编辑页'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '新标题');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('打开编辑页'), findsOneWidget, reason: '保存后应回到宿主页');
    final updated = (await repo.allTasks()).single;
    expect(updated.title, '新标题');
  });
}
