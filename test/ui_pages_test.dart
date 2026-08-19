import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/ui/pages/task_edit_page.dart';
import 'package:verb_app/ui/pages/recycle_bin_page.dart';

void main() {
  testWidgets('编辑页修改标题后保存', (tester) async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final t = await svc.create(title: '旧标题');
    await tester.pumpWidget(MaterialApp(home: TaskEditPage(task: t, service: svc)));

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

    await tester.pumpWidget(MaterialApp(home: RecycleBinPage(service: svc)));
    await tester.pumpAndSettle();
    expect(find.text('待删'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.restore));
    await tester.pumpAndSettle();
    expect(find.text('待删'), findsNothing);

    final all = await repo.allTasks();
    expect(all.single.deleted, isFalse);
  });
}

