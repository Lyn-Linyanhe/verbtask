import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';

/// 回归：搜索无结果时应提示“未找到相关事项”，而非误显示“收件箱是空的”。
void main() {
  testWidgets('搜索无结果显示专门空态，可一键清除搜索', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    await svc.create(title: '交周报');

    await tester.pumpWidget(
        VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();

    // 输入一个绝对无匹配的词
    await tester.enterText(find.byType(TextField).at(1), 'zzz不存在');
    await tester.pumpAndSettle();

    expect(find.text('未找到相关事项'), findsOneWidget);
    expect(find.text('收件箱是空的'), findsNothing, reason: '搜索无结果不应误显示“收件箱是空的”');
    expect(find.text('交周报'), findsNothing);

    // 一键清除搜索 → 任务恢复显示
    await tester.tap(find.text('清除搜索'));
    await tester.pumpAndSettle();
    expect(find.text('交周报'), findsOneWidget);
  });
}
