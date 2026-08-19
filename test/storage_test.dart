import 'dart:io';
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
}
