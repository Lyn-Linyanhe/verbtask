import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/app.dart';

void main() {
  test('Today 查询的本地日期边界可排除下一天', () async {
    final service = TaskService(InMemoryRepository());
    await service.create(
      title: '今天',
      due: DueDate(DateTime.utc(2026, 1, 10, 9)),
    );
    await service.create(
      title: '明天',
      due: DueDate(DateTime.utc(2026, 1, 11, 9)),
    );

    final result = await service.query(
      dueFrom: DateTime.utc(2026, 1, 10),
      dueTo: DateTime.utc(2026, 1, 11),
      includeDone: false,
    );

    expect(result.map((task) => task.title), contains('今天'));
    expect(result.map((task) => task.title), isNot(contains('明天')));
  });

  test('Inbox 查询只返回未归入清单的任务', () async {
    final service = TaskService(InMemoryRepository());
    final list = await service.createList(name: '工作');
    await service.create(title: '收件箱任务');
    await service.create(title: '清单任务', listId: list.id);

    final result = await service.query(inboxOnly: true);

    expect(result.map((task) => task.title), ['收件箱任务']);
  });

  testWidgets('快速录入的 hashtag 会匹配现有清单并从标题移除', (tester) async {
    final repo = InMemoryRepository();
    final list = await TaskService(repo).createList(name: '工作');

    await tester.pumpWidget(
        VerbApp(repository: repo, initialLocale: const Locale('zh')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '明天交周报 #工作');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('清单：工作'), findsOneWidget);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    final task = (await repo.allTasks()).single;
    expect(task.title, '交周报');
    expect(task.listId, list.id);
  });
}
