import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/storage/file_repository.dart';
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

    final server = SyncServer(serverRepo);
    await server.start();
    final client = SyncClient(Uri.parse('http://127.0.0.1:${server.port}/'));
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

    final server = SyncServer(serverRepo);
    await server.start();
    final client = SyncClient(Uri.parse('http://127.0.0.1:${server.port}/'));
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
    final server = SyncServer(serverRepo);
    await server.start();
    var callbackCalled = false;
    try {
      final ran = await SyncController.quickSync(
        clientRepo,
        discover: () async => [LanPeer('127.0.0.1', server.port)],
        onSynced: () async => callbackCalled = true,
      );

      expect(ran, 1);
      expect(callbackCalled, isTrue);
    } finally {
      await server.stop();
    }
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
    final server = SyncServer(serverRepo);
    await server.start();
    final client = SyncClient(Uri.parse('http://127.0.0.1:${server.port}/'));
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
    final server = SyncServer(serverRepo);
    await server.start();
    final client = SyncClient(Uri.parse('http://127.0.0.1:${server.port}/'));
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
    final server = SyncServer(serverRepo);
    await server.start();
    final client = SyncClient(Uri.parse('http://127.0.0.1:${server.port}/'));
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
}
