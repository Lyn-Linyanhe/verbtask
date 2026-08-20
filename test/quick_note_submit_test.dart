import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/l10n/generated/app_localizations.dart';
import 'package:verb_app/ui/pages/quick_note_page.dart';

void main() {
  Widget wrap(Widget w) => MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: w,
      );

  testWidgets('速记页：多行+newline 下回车能触发保存', (tester) async {
    tester.view.physicalSize = const Size(600, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var saved = false;
    String? savedText;
    await tester.pumpWidget(wrap(QuickNotePage(
      onAdd: (text) async {
        saved = true;
        savedText = text;
        return;
      },
    )));
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    await tester.enterText(field, '速记任务');
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pumpAndSettle();
    expect(saved, isTrue, reason: 'onSubmitted 应被 newline 触发');
    expect(savedText, '速记任务');
  });
}
