import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';

void main() {
  testWidgets('英语默认收件箱显示 Inbox', (tester) async {
    await tester.pumpWidget(VerbApp(
      repository: InMemoryRepository(),
      initialLocale: const Locale('en'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Inbox'), findsOneWidget);
  });

  testWidgets('通过设置切换到中文', (tester) async {
    await tester.pumpWidget(VerbApp(
      repository: InMemoryRepository(),
      initialLocale: const Locale('en'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中文'));
    await tester.pumpAndSettle();
    expect(find.text('收件箱'), findsOneWidget);
  });
}
