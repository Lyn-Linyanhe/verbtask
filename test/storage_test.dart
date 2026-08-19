import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/storage/backup_service.dart';
import 'package:verb_app/core/storage/file_repository.dart';

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
    await repo.upsertList(TaskList(id: 'l', name: '生活', updatedAt: DateTime.utc(2026,1,1)));

    final repo2 = FileRepository(f); // 重新加载
    expect((await repo2.allTasks()).length, 1);
    expect((await repo2.allTasks()).first.title, '买菜');
    expect((await repo2.allLists()).first.name, '生活');
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
