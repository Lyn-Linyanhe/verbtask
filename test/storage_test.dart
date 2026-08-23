import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/storage/backup_service.dart';
import 'package:verb_app/core/storage/file_repository.dart';
import 'package:verb_app/core/services/task_service.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('verb_test_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('FileRepository 持久化到磁盘并可重读', () async {
    final f = File('${dir.path}/data.json');
    final repo = FileRepository(f);
    await repo.upsertTask(Task(
      id: 'a',
      title: '买菜',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ));
    await repo.upsertList(
        TaskList(id: 'l', name: '生活', updatedAt: DateTime.utc(2026, 1, 1)));

    final repo2 = FileRepository(f); // 重新加载
    expect((await repo2.allTasks()).length, 1);
    expect((await repo2.allTasks()).first.title, '买菜');
    expect((await repo2.allLists()).first.name, '生活');
  });

  test('同一仓库并发写入不会丢失任一任务', () async {
    final repo = FileRepository(File('${dir.path}/concurrent.json'));
    final first = Task(
      id: 'first',
      title: '第一条',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final second = Task(
      id: 'second',
      title: '第二条',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );

    await Future.wait([repo.upsertTask(first), repo.upsertTask(second)]);

    expect((await repo.allTasks()).map((task) => task.id).toSet(),
        {'first', 'second'});
  });

  test('不同仓库实例写入同一文件不会覆盖另一实例的新任务', () async {
    final f = File('${dir.path}/cross-instance.json');
    final firstRepo = FileRepository(f);
    final secondRepo = FileRepository(f);

    await firstRepo.upsertTask(Task(
      id: 'first',
      title: '前台写入',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    await secondRepo.upsertTask(Task(
      id: 'second',
      title: '后台写入',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ));

    final reloaded = FileRepository(f);
    expect((await reloaded.allTasks()).map((task) => task.id).toSet(),
        {'first', 'second'});
  });

  test('永久删除墓碑不会被旧编辑对象重新写回', () async {
    final repo = FileRepository(File('${dir.path}/tombstone-guard.json'));
    final oldTask = Task(
      id: 'gone',
      title: '旧标题',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      version: 1,
      changeId: 'gone-v1',
    );
    await repo.upsertTombstone(TaskTombstone(
      id: 'gone',
      updatedAt: DateTime.utc(2026, 1, 2),
      version: 2,
      changeId: 'gone-delete-v2',
    ));

    await repo.upsertTask(oldTask);

    expect(await repo.allTasks(), isEmpty);
    expect((await repo.allTombstones()).single.changeId, 'gone-delete-v2');
  });

  test('写入失败时不移除已有数据文件', () async {
    final f = File('${dir.path}/data.json');
    final repo = FileRepository(f);
    await repo.upsertTask(Task(
      id: 'a',
      title: '已有数据',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ));
    final before = await f.readAsString();

    // 占用预期的临时路径，模拟临时文件无法写入；原文件内容应保持不变。
    await Directory('${f.path}.tmp').create();
    await expectLater(
      repo.upsertTask(Task(
        id: 'b',
        title: '不会覆盖',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      )),
      throwsA(isA<FileSystemException>()),
    );
    expect(await f.readAsString(), before);
  });

  test('普通写入失败时同一仓库的任务和变更日志不变', () async {
    final f = File('${dir.path}/state.json');
    final repo = FileRepository(f);
    final original = Task(
      id: 'a',
      title: '已有任务',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    await repo.upsertTask(original);
    final list = TaskList(
      id: 'l',
      name: '已有清单',
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    await repo.upsertList(list);
    await Directory('${f.path}.tmp').create();

    await expectLater(
      repo.upsertTask(Task(
        id: 'b',
        title: '不会落盘',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      )),
      throwsA(isA<FileSystemException>()),
    );

    expect((await repo.allTasks()).map((task) => task.id), ['a']);
    expect((await repo.allLists()).single.id, list.id);
    final changes = await repo.changesSince(null);
    expect(changes.length, 1);
    expect(changes.single.changeId, original.changeId);
  });

  test('删除清单的批量写入失败时不产生部分迁移', () async {
    final f = File('${dir.path}/data.json');
    final repo = FileRepository(f);
    final service = TaskService(repo);
    final list = await service.createList(name: '工作');
    await service.create(title: '一号', listId: list.id);
    await service.create(title: '二号', listId: list.id);
    final before = await f.readAsString();
    await Directory('${f.path}.tmp').create();

    await expectLater(
        service.deleteList(list), throwsA(isA<FileSystemException>()));

    expect(await f.readAsString(), before);
    final reloaded = FileRepository(f);
    expect((await reloaded.allLists()).single.id, list.id);
    expect((await reloaded.allTasks()).every((task) => task.listId == list.id),
        isTrue);
  });

  test('删除清单成功后为每个迁移任务保留变更日志', () async {
    final f = File('${dir.path}/changes.json');
    final repo = FileRepository(f);
    final service = TaskService(repo);
    final list = await service.createList(name: '工作');
    final first = await service.create(title: '一号', listId: list.id);
    final second = await service.create(title: '二号', listId: list.id);

    await service.deleteList(list);

    final changes = await repo.changesSince(null);
    final moved = changes
        .where(
            (change) => change.taskId == first.id || change.taskId == second.id)
        .toList();
    expect(moved.length, 4);
    expect(moved.skip(2).every((change) => change.kind == 'upsert'), isTrue);
    expect(moved.skip(2).map((change) => change.changeId).toSet().length, 2);

    final reloaded = FileRepository(f);
    expect((await reloaded.changesSince(null)).length, changes.length);
  });

  test('旧 JSON 缺少 changeId 仍可读取', () {
    final json = Task(
      id: 'legacy',
      title: '旧任务',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ).toJson()
      ..remove('changeId');

    final task = Task.fromJson(json);

    expect(task.title, '旧任务');
    expect(task.changeId, isNotEmpty);
  });

  test('备份导出/导入 round-trip', () async {
    final repo = FileRepository(File('${dir.path}/d1.json'));
    final repo2 = FileRepository(File('${dir.path}/d2.json'));
    final service = BackupService(repo);
    await repo.upsertTask(Task(
      id: 'x',
      title: '写周报',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 3),
    ));
    final exported = await service.exportJson();

    final imp = BackupService(repo2);
    final n = await imp.importJson(exported);
    expect(n, 1);
    final all = await repo2.allTasks();
    expect(all.single.id, 'x');
    expect(all.single.title, '写周报');
  });

  test('CSV 导出/导入 round-trip', () async {
    final repo = FileRepository(File('${dir.path}/c1.json'));
    final repo2 = FileRepository(File('${dir.path}/c2.json'));
    final svc = TaskService(repo);
    final list = await svc.createList(name: '工作');
    await svc.create(
      title: '写周报,含逗号"引号"\n换行',
      notes: '备注',
      listId: list.id,
      due: DueDate(DateTime.utc(2026, 8, 25, 10)),
      priority: 3,
    );
    final csv = await BackupService(repo).exportCsv();

    final imp = BackupService(repo2);
    final n = await imp.importCsv(csv);
    expect(n, 1);
    final t = (await repo2.allTasks()).single;
    expect(t.title, '写周报,含逗号"引号"\n换行');
    expect(t.notes, '备注');
    expect(t.due?.value.toUtc(), DateTime.utc(2026, 8, 25, 10));
    expect(t.due?.dateOnly, isFalse);
    expect(t.priority, 3);
    expect(t.listId, list.id);
  });

  test('导入不支持版本的 JSON 时不改动已有数据', () async {
    final f = File('${dir.path}/v.json');
    final repo = FileRepository(f);
    await repo.upsertTask(Task(
      id: 'keep',
      title: '保留',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ));
    final before = await f.readAsString();
    final bad = jsonEncode({
      'format': 'verb-app',
      'version': 999,
      'tasks': <Object>[],
      'lists': <Object>[],
    });

    await expectLater(
      BackupService(repo).importJson(bad),
      throwsA(isA<FormatException>()),
    );
    expect(await f.readAsString(), before);
    expect((await repo.allTasks()).single.id, 'keep');
  });

  test('损坏数据抛出带恢复副本路径的异常且保留原文件', () async {
    final f = File('${dir.path}/broken.json');
    const original = '{"version":1,"tasks":[{"id":';
    await f.writeAsString(original);

    StorageLoadException? error;
    try {
      FileRepository(f);
    } on StorageLoadException catch (e) {
      error = e;
    }

    expect(error, isNotNull);
    expect(error!.filePath, f.path);
    expect(error.recoveryPath, isNotNull);
    expect(await f.readAsString(), original);
    expect(await File(error.recoveryPath!).exists(), isTrue);
  });

  test('未来 schema 版本拒绝加载且不覆盖原文件', () async {
    final f = File('${dir.path}/future.json');
    final original = jsonEncode({
      'version': 999,
      'tasks': const [],
      'lists': const [],
      'changes': const [],
    });
    await f.writeAsString(original);

    expect(() => FileRepository(f), throwsA(isA<StorageLoadException>()));
    expect(await f.readAsString(), original);
    final copies = f.parent
        .listSync()
        .whereType<File>()
        .where((candidate) => candidate.path.contains('.corrupt-'));
    expect(copies, isNotEmpty);
  });

  test('JSON 导入遇到坏记录时保持仓库与磁盘不变', () async {
    final f = File('${dir.path}/atomic.json');
    final repo = FileRepository(f);
    await repo.upsertTask(Task(
      id: 'keep',
      title: '原有任务',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    final before = await f.readAsString();
    final valid = Task(
      id: 'new',
      title: '应该回滚',
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 2),
    ).toJson();
    final bad = jsonEncode({
      'format': 'verb-app',
      'version': 1,
      'tasks': [
        valid,
        {'id': 'broken', 'title': 42}
      ],
      'lists': const [],
    });

    expect(
      BackupService(repo).importJson(bad),
      throwsA(anyOf(isA<TypeError>(), isA<FormatException>())),
    );
    expect(await f.readAsString(), before);
    expect((await repo.allTasks()).map((task) => task.id), ['keep']);
  });
}
