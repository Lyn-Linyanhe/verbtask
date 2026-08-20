import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';

/// 回归：空收件箱给新手引导（示例自然语言录入）。
void main() {
  testWidgets('空收件箱显示新手引导文案', (tester) async {
    final repo = InMemoryRepository();
    await tester.pumpWidget(VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    expect(find.text('收件箱是空的'), findsOneWidget);
    expect(find.textContaining('明天下午3点'), findsOneWidget,
        reason: '空态副文案应包含自然语言示例');
  });
}
