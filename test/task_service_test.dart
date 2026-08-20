import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';

class FailingBatchRepository extends InMemoryRepository {
  @override
  Future<void> replaceTasksAndRemoveList(
      String listId, List<Task> tasks) async {
    throw StateError('simulated batch failure');
  }
}

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

  test('查询支持截止时间的左闭右开边界', () async {
    final svc = TaskService(InMemoryRepository());
    await svc.create(title: '边界内', due: DueDate(DateTime.utc(2026, 1, 10, 9)));
    await svc.create(title: '上界', due: DueDate(DateTime.utc(2026, 1, 11)));
    await svc.create(title: '无日期', due: null);

    final q = await svc.query(
      dueFrom: DateTime.utc(2026, 1, 10),
      dueTo: DateTime.utc(2026, 1, 11),
    );

    expect(q.map((t) => t.title), ['边界内']);
  });

  test('查询支持标题排序和排除已完成任务', () async {
    final svc = TaskService(InMemoryRepository());
    await svc.create(title: 'Zeta');
    final done = await svc.create(title: 'Alpha', status: TaskStatus.done);

    final active = await svc.query(by: BySort.titleAsc, includeDone: false);
    expect(active.map((t) => t.title), ['Zeta']);

    final all = await svc.query(status: TaskStatus.done, includeDone: false);
    expect(all.single.id, done.id);
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
    final editedAgain = await service.edit(edited, title: '新任务 2');

    expect(edited.changeId, isNot(task.changeId));
    expect(edited.changeId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(editedAgain.changeId, isNot(edited.changeId));
  });

  test('编辑清单会持久化名称和排序', () async {
    final service = TaskService(InMemoryRepository());
    final list = await service.createList(name: '工作');

    final edited = await service.editList(
      list,
      name: '重要工作',
      color: '#4455AA',
      sortOrder: 2,
    );

    expect(edited.name, '重要工作');
    expect(edited.color, '#4455AA');
    expect(edited.sortOrder, 2);
  });

  test('删除清单的批量写入失败时不改变任务归属', () async {
    final repo = FailingBatchRepository();
    final service = TaskService(repo);
    final list = await service.createList(name: '工作');
    await service.create(title: '报告', listId: list.id);

    await expectLater(
      service.deleteList(list),
      throwsA(isA<StateError>()),
    );

    expect((await repo.allLists()).single.id, list.id);
    expect((await repo.allTasks()).single.listId, list.id);
  });
}
