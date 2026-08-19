import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';

void main() {
  test('创建/编辑/回收站/恢复/彻底删除', () async {
    final svc = TaskService(InMemoryRepository());
    final t =
        await svc.create(title: '买牛奶', due: DueDate(DateTime.utc(2026, 1, 5)));
    expect(t.title, '买牛奶');
    expect(t.version, 1);

    final edited = await svc.edit(t, title: '买两盒牛奶');
    expect(edited.title, '买两盒牛奶');
    expect(edited.version, 2);

    final recycled = await svc.recycle(edited);
    expect(recycled.deleted, isTrue);

    var q = await svc.query();
    expect(q, isEmpty); // 回收站内默认不显示

    final restored = await svc.restore(recycled);
    expect(restored.deleted, isFalse);
    expect((await svc.query()).length, 1);

    await svc.deletePermanent(restored);
    expect((await svc.query()), isEmpty);
  });

  test('按截止时间排序', () async {
    final svc = TaskService(InMemoryRepository());
    await svc.create(title: '晚', due: DueDate(DateTime.utc(2026, 2, 1)));
    await svc.create(title: '早', due: DueDate(DateTime.utc(2026, 1, 1)));
    final q = await svc.query();
    expect(q.first.title, '早');
  });

  test('删除清单会把任务移回收件箱并移除清单', () async {
    final repo = InMemoryRepository();
    final service = TaskService(repo);
    final list = await service.createList(name: '工作');
    await service.create(title: '报告', listId: list.id);

    await service.deleteList(list);

    expect((await repo.allLists()), isEmpty);
    expect((await repo.allTasks()).single.listId, isNull);
  });

  test('任务编辑生成新的唯一 changeId', () async {
    final service = TaskService(InMemoryRepository());
    final task = await service.create(title: '原任务');
    final edited = await service.edit(task, title: '新任务');

    expect(edited.changeId, isNot(task.changeId));
    expect(edited.changeId, matches(RegExp(r'^[0-9a-f-]{36}$')));
  });
}
