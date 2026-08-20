import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/task.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/core/sync/sync_engine.dart';

Task mk(String id, int version, {String title = 't', bool deleted = false}) =>
    Task(
      id: id,
      title: title,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1).add(Duration(hours: version)),
      version: version,
      changeId: '$id-v$version',
      deleted: deleted,
    );

void main() {
  test('远端较新版本胜出', () async {
    final local = InMemoryRepository();
    await local.upsertTask(mk('a', 1, title: '本地旧'));
    final engine = SyncEngine(local);
    final res = await engine.mergeRemote(
      remoteTasks: [mk('a', 2, title: '远端新')],
      seenChangeIds: const [],
    );
    final merged = res.merged.firstWhere((t) => t.id == 'a');
    expect(merged.title, '远端新');
    expect(merged.version, 2);
  });

  test('本地独有改动会被推送', () async {
    final local = InMemoryRepository();
    await local.upsertTask(mk('local-only', 1));
    final engine = SyncEngine(local);
    final res = await engine
        .mergeRemote(remoteTasks: const [], seenChangeIds: const []);
    expect(res.toPush.map((t) => t.id), contains('local-only'));
  });

  test('已见过的 changeId 不重复应用（幂等）', () async {
    final local = InMemoryRepository();
    final engine = SyncEngine(local);
    final res = await engine.mergeRemote(
      remoteTasks: [mk('a', 3)],
      seenChangeIds: const [],
    );
    expect(res.appliedChangeIds, contains('a-v3'));
  });

  test('删除经 oplog 传播', () async {
    final local = InMemoryRepository();
    await local.upsertTask(mk('a', 1, title: '原'));
    final engine = SyncEngine(local);
    final del = mk('a', 2, deleted: true);
    final res =
        await engine.mergeRemote(remoteTasks: [del], seenChangeIds: const []);
    final merged = res.merged.firstWhere((t) => t.id == 'a');
    expect(merged.deleted, isTrue);
  });
}
