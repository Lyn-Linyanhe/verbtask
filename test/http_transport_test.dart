import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/storage/file_repository.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/sync/http_transport.dart';
import 'package:verb_app/core/sync/lan_discovery.dart';
import 'package:verb_app/core/sync/sync_controller.dart';
import 'package:verb_app/core/sync/sync_engine.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('verb_sync_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('Server/Client 双向同步后收敛', () async {
    final serverRepo = FileRepository(File('${dir.path}/server.json'));
    final clientRepo = FileRepository(File('${dir.path}/client.json'));

    // Windows(Server) 已有任务 A
    await serverRepo.upsertTask(Task(
      id: 'A',
      title: '服务端任务',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    // Android(Client) 已有任务 B
    await clientRepo.upsertTask(Task(
      id: 'B',
      title: '客户端任务',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ));

    final server = SyncServer(serverRepo, token: 'test-token');
    await server.start();
    final client = SyncClient(Uri.parse('http://127.0.0.1:${server.port}/'),
        token: 'test-token');
    try {
      final engine = SyncEngine(clientRepo);
      await runSync(client, engine); // 拉 A + 推 B

      final serverTasks = await serverRepo.allTasks();
      expect(serverTasks.map((t) => t.id).toSet(), {'A', 'B'});
      final clientTasks = await clientRepo.allTasks();
      expect(clientTasks.map((t) => t.id).toSet(), {'A', 'B'});
    } finally {
      await server.stop();
    }
  });

  test('远端较新版本在同步中胜出', () async {
    final serverRepo = FileRepository(File('${dir.path}/s.json'));
    final clientRepo = FileRepository(File('${dir.path}/c.json'));
    // 同一任务，Server 版本更高
    await serverRepo.upsertTask(Task(
      id: 'X',
      title: '服务端新版',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 3),
      version: 2,
      changeId: 'X-v2',
    ));
    await clientRepo.upsertTask(Task(
      id: 'X',
      title: '客户端旧版',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      version: 1,
      changeId: 'X-v1',
    ));

    final server = SyncServer(serverRepo, token: 'test-token');
    await server.start();
    final client = SyncClient(Uri.parse('http://127.0.0.1:${server.port}/'),
        token: 'test-token');
    try {
      final engine = SyncEngine(clientRepo);
      await runSync(client, engine);
      final merged =
          (await clientRepo.allTasks()).firstWhere((t) => t.id == 'X');
      expect(merged.title, '服务端新版');
    } finally {
      await server.stop();
    }
  });

  test('快速同步成功后调用完成回调', () async {
    final serverRepo = FileRepository(File('${dir.path}/callback-server.json'));
    final clientRepo = FileRepository(File('${dir.path}/callback-client.json'));
    await serverRepo.upsertTask(Task(
      id: 'callback',
      title: '服务端任务',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    final server = SyncServer(serverRepo, token: 'test-token');
    await server.start();
    var callbackCalled = false;
    try {
      final ran = await SyncController.quickSync(
        clientRepo,
        discover: () async => [LanPeer('127.0.0.1', server.port)],
        onSynced: () async => callbackCalled = true,
        token: 'test-token',
      );

      expect(ran, 1);
      expect(callbackCalled, isTrue);
    } finally {
      await server.stop();
    }
  });

  test('快速同步未发现 Windows 主机时报告失败而不是静默返回 0', () async {
    Object? reported;

    await expectLater(
      SyncController.quickSync(
        InMemoryRepository(),
        discover: () async => const [],
        onError: (error) async => reported = error,
        token: 'test-token',
      ),
      throwsA(isA<StateError>()),
    );

    expect(reported, isA<StateError>());
  });

  test('未授权请求被 401 拒绝', () async {
    final serverRepo = FileRepository(File('${dir.path}/auth-server.json'));
    await serverRepo.upsertTask(Task(
      id: 'A',
      title: '秘密任务',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    final server = SyncServer(serverRepo, token: 'secret');
    await server.start();
    try {
      final anon = SyncClient(Uri.parse('http://127.0.0.1:${server.port}/'));
      await expectLater(anon.pullSnapshot(), throwsA(isA<StateError>()));
      await expectLater(
          anon.push(const [], const []), throwsA(isA<StateError>()));
      // 数据未被未授权读取
      expect((await serverRepo.allTasks()).length, 1);
    } finally {
      await server.stop();
    }
  });

  test('生产服务未配置 token 时也拒绝请求', () async {
    final serverRepo = FileRepository(File('${dir.path}/missing-token.json'));
    final server = SyncServer(serverRepo);
    await server.start();
    try {
      final anon = SyncClient(Uri.parse('http://127.0.0.1:${server.port}/'));
      await expectLater(anon.pullSnapshot(), throwsA(isA<StateError>()));
      await expectLater(
        anon.push(const [], const []),
        throwsA(isA<StateError>()),
      );
    } finally {
      await server.stop();
    }
  });

  test('pull after cursor 只返回 cursor 之后变更的任务', () async {
    final serverRepo = FileRepository(File('${dir.path}/cursor-server.json'));
    await serverRepo.upsertTask(Task(
      id: 'first',
      title: '第一次变更',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    final server = SyncServer(serverRepo, token: 'secret');
    await server.start();
    final client = SyncClient(
      Uri.parse('http://127.0.0.1:${server.port}/'),
      token: 'secret',
    );
    try {
      final first = await client.pullSnapshot();
      expect(first.tasks.map((task) => task.id), ['first']);
      await serverRepo.upsertTask(Task(
        id: 'second',
        title: '第二次变更',
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      ));
      final next = await client.pullSnapshot(after: first.cursor);
      expect(next.tasks.map((task) => task.id), ['second']);
      expect(next.cursor, isNot(first.cursor));
    } finally {
      await server.stop();
    }
  });

  test('带新 changeId 的旧任务不能覆盖服务端较新版本', () async {
    final serverRepo = FileRepository(File('${dir.path}/stale-server.json'));
    await serverRepo.upsertTask(Task(
      id: 'same',
      title: '服务端新版本',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 3),
      version: 3,
      changeId: 'server-v3',
    ));
    final server = SyncServer(serverRepo, token: 'secret');
    await server.start();
    try {
      final client = SyncClient(
        Uri.parse('http://127.0.0.1:${server.port}/'),
        token: 'secret',
      );
      await client.push([
        Task(
          id: 'same',
          title: '客户端旧版本',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
          version: 1,
          changeId: 'fresh-but-stale',
        ),
      ], const []);
      expect((await serverRepo.allTasks()).single.title, '服务端新版本');
    } finally {
      await server.stop();
    }
  });

  test('push exposes server-rejected change ids to the caller', () async {
    final serverRepo = FileRepository(File('${dir.path}/rejected-server.json'));
    await serverRepo.upsertTask(Task(
      id: 'same-result',
      title: '服务端较新',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 3),
      version: 3,
      changeId: 'server-result-v3',
    ));
    final server = SyncServer(serverRepo, token: 'secret');
    await server.start();
    try {
      final client = SyncClient(
        Uri.parse('http://127.0.0.1:${server.port}/'),
        token: 'secret',
      );
      final result = await client.push([
        Task(
          id: 'same-result',
          title: '客户端旧版本',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
          version: 1,
          changeId: 'client-rejected-v1',
        ),
      ], const []);

      expect(result.rejectedChangeIds, contains('client-rejected-v1'));
    } finally {
      await server.stop();
    }
  });

  test('正确令牌可双向同步', () async {
    final serverRepo = FileRepository(File('${dir.path}/ok-s.json'));
    final clientRepo = FileRepository(File('${dir.path}/ok-c.json'));
    await serverRepo.upsertTask(Task(
      id: 'S',
      title: '服务端',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    await clientRepo.upsertTask(Task(
      id: 'C',
      title: '客户端',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ));
    final server = SyncServer(serverRepo, token: 'secret');
    await server.start();
    final client = SyncClient(
      Uri.parse('http://127.0.0.1:${server.port}/'),
      token: 'secret',
    );
    try {
      final engine = SyncEngine(clientRepo);
      await runSync(client, engine);
      expect(
          (await serverRepo.allTasks()).map((t) => t.id).toSet(), {'S', 'C'});
      expect(
          (await clientRepo.allTasks()).map((t) => t.id).toSet(), {'S', 'C'});
    } finally {
      await server.stop();
    }
  });

  test('清单随同步收敛', () async {
    final serverRepo = FileRepository(File('${dir.path}/list-s.json'));
    final clientRepo = FileRepository(File('${dir.path}/list-c.json'));
    await serverRepo.upsertList(
        TaskList(id: 'L1', name: '服务端清单', updatedAt: DateTime.utc(2026, 1, 1)));
    await clientRepo.upsertList(
        TaskList(id: 'L2', name: '客户端清单', updatedAt: DateTime.utc(2026, 1, 1)));
    final server = SyncServer(serverRepo, token: 'test-token');
    await server.start();
    final client = SyncClient(Uri.parse('http://127.0.0.1:${server.port}/'),
        token: 'test-token');
    try {
      final engine = SyncEngine(clientRepo);
      await runSync(client, engine);
      expect(
          (await serverRepo.allLists()).map((l) => l.id).toSet(), {'L1', 'L2'});
      expect(
          (await clientRepo.allLists()).map((l) => l.id).toSet(), {'L1', 'L2'});
    } finally {
      await server.stop();
    }
  });

  test('删除墓碑经同步传播', () async {
    final serverRepo = FileRepository(File('${dir.path}/del-s.json'));
    final clientRepo = FileRepository(File('${dir.path}/del-c.json'));
    await serverRepo.upsertTask(Task(
      id: 'X',
      title: '原任务',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      version: 1,
      changeId: 'X-v1',
    ));
    await clientRepo.upsertTask(Task(
      id: 'X',
      title: '原任务',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      version: 2,
      changeId: 'X-v2',
      deleted: true,
    ));
    final server = SyncServer(serverRepo, token: 'test-token');
    await server.start();
    final client = SyncClient(Uri.parse('http://127.0.0.1:${server.port}/'),
        token: 'test-token');
    try {
      final engine = SyncEngine(clientRepo);
      await runSync(client, engine);
      final serverTask = (await serverRepo.allTasks()).single;
      expect(serverTask.deleted, isTrue);
    } finally {
      await server.stop();
    }
  });

  test('重复同步幂等（收敛后不再推送）', () async {
    final serverRepo = FileRepository(File('${dir.path}/idem-s.json'));
    final clientRepo = FileRepository(File('${dir.path}/idem-c.json'));
    await serverRepo.upsertTask(Task(
      id: 'A',
      title: 'A',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    final server = SyncServer(serverRepo, token: 'test-token');
    await server.start();
    final client = SyncClient(Uri.parse('http://127.0.0.1:${server.port}/'),
        token: 'test-token');
    try {
      final engine = SyncEngine(clientRepo);
      await runSync(client, engine);
      final serverChangeCount = (await serverRepo.changesSince(null)).length;
      await runSync(client, engine); // 再次同步
      expect((await serverRepo.changesSince(null)).length, serverChangeCount);
      expect((await serverRepo.allTasks()).length, 1);
    } finally {
      await server.stop();
    }
  });

  test('runSync 成功应用后提交游标，下一次只拉取游标之后的变更', () async {
    final serverRepo = FileRepository(File('${dir.path}/cursor-run-s.json'));
    final clientRepo = FileRepository(File('${dir.path}/cursor-run-c.json'));
    await serverRepo.upsertTask(Task(
      id: 'first',
      title: '第一条',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    final server = SyncServer(serverRepo, token: 'test-token');
    await server.start();
    final client = SyncClient(
      Uri.parse('http://127.0.0.1:${server.port}/'),
      token: 'test-token',
    );
    var cursor = '';
    try {
      final engine = SyncEngine(clientRepo);
      await runSync(
        client,
        engine,
        onCursorCommitted: (value) async => cursor = value,
      );
      expect(cursor, isNotEmpty);
      await serverRepo.upsertTask(Task(
        id: 'second',
        title: '第二条',
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      ));
      await runSync(
        client,
        engine,
        after: cursor,
        onCursorCommitted: (value) async => cursor = value,
      );
      expect((await clientRepo.allTasks()).map((task) => task.id).toSet(),
          {'first', 'second'});
    } finally {
      await server.stop();
    }
  });

  test('增量拉取没有远端变更时不重复推送已同步任务', () async {
    final serverRepo = FileRepository(File('${dir.path}/incremental-s.json'));
    final clientRepo = FileRepository(File('${dir.path}/incremental-c.json'));
    await serverRepo.upsertTask(Task(
      id: 'stable',
      title: '已同步任务',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    final server = SyncServer(serverRepo, token: 'test-token');
    await server.start();
    final client = SyncClient(
      Uri.parse('http://127.0.0.1:${server.port}/'),
      token: 'test-token',
    );
    var cursor = '';
    try {
      final engine = SyncEngine(clientRepo);
      await runSync(client, engine,
          onCursorCommitted: (value) async => cursor = value);
      final changes = (await serverRepo.changesSince(null)).length;

      await runSync(client, engine,
          after: cursor, onCursorCommitted: (value) async => cursor = value);

      expect((await serverRepo.changesSince(null)).length, changes);
    } finally {
      await server.stop();
    }
  });

  test('彻底删除通过墓碑同步且不会复活', () async {
    final serverRepo = FileRepository(File('${dir.path}/tomb-s.json'));
    final clientRepo = FileRepository(File('${dir.path}/tomb-c.json'));
    final serverTask = Task(
      id: 'gone',
      title: '应该删除',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    await serverRepo.upsertTask(serverTask);
    await clientRepo.upsertTask(serverTask);
    final service = TaskService(clientRepo);
    await service.deletePermanent(serverTask);

    final server = SyncServer(serverRepo, token: 'test-token');
    await server.start();
    final client = SyncClient(
      Uri.parse('http://127.0.0.1:${server.port}/'),
      token: 'test-token',
    );
    try {
      await runSync(client, SyncEngine(clientRepo));
      expect(
          (await serverRepo.allTasks()).where((t) => t.id == 'gone'), isEmpty);
      expect(
          (await clientRepo.allTasks()).where((t) => t.id == 'gone'), isEmpty);
      expect((await serverRepo.allTombstones()).map((t) => t.id),
          contains('gone'));
      expect((await clientRepo.allTombstones()).map((t) => t.id),
          contains('gone'));
    } finally {
      await server.stop();
    }
  });

  test('删除清单保留墓碑并在同步后不重新出现', () async {
    final serverRepo = FileRepository(File('${dir.path}/list-tomb-s.json'));
    final clientRepo = FileRepository(File('${dir.path}/list-tomb-c.json'));
    final list = TaskList(
      id: 'list-gone',
      name: '已删除清单',
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    await serverRepo.upsertList(list);
    await clientRepo.upsertList(list);
    await TaskService(clientRepo).deleteList(list);

    final server = SyncServer(serverRepo, token: 'test-token');
    await server.start();
    final client = SyncClient(
      Uri.parse('http://127.0.0.1:${server.port}/'),
      token: 'test-token',
    );
    try {
      await runSync(client, SyncEngine(clientRepo));
      expect(await serverRepo.allLists(), isEmpty);
      expect(await clientRepo.allLists(), isEmpty);
      expect((await serverRepo.allLists(includeDeleted: true)).single.deleted,
          isTrue);
    } finally {
      await server.stop();
    }
  });
}
