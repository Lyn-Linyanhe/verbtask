import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';

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
}
