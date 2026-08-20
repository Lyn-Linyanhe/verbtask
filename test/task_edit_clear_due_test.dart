import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/l10n/generated/app_localizations.dart';
import 'package:verb_app/ui/pages/task_edit_page.dart';

Widget le(Widget home) => MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  testWidgets('编辑页清除截止日期后保存', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final t =
        await svc.create(title: '清洁', due: DueDate(DateTime.utc(2026, 9, 1, 10)));
    await tester.pumpWidget(le(TaskEditPage(task: t, service: svc)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.clear_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.clear_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final updated = (await repo.allTasks()).single;
    expect(updated.due, isNull);
  });
}

