import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/l10n/generated/app_localizations.dart';
import 'package:verb_app/ui/pages/task_edit_page.dart';

void main() {
  testWidgets('重复任务保存前选择范围，选择仅此次会写入覆盖', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = InMemoryRepository();
    final service = TaskService(repo);
    final occurrence = DateTime.utc(2026, 1, 2, 9);
    final task = await service.create(
      title: '原始标题',
      due: DueDate(DateTime.utc(2026, 1, 1, 9)),
      rrule: 'FREQ=DAILY',
    );

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: TaskEditPage(
        task: task,
        service: service,
        occurrence: occurrence,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '仅此次标题');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('编辑重复事项'), findsOneWidget);
    expect(find.text('仅此次'), findsOneWidget);
    expect(find.text('此次及以后'), findsOneWidget);
    expect(find.text('整个系列'), findsOneWidget);
    await tester.tap(find.text('仅此次'));
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    final updated = (await repo.allTasks()).single;
    expect(
        updated.occurrenceOverrides[occurrenceKey(occurrence)]?.title, '仅此次标题');
  });
}
