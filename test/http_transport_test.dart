import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/storage/file_repository.dart';
import 'package:verb_app/core/sync/http_transport.dart';
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
      id: 'A', title: '服务端任务',
      createdAt: DateTime.utc(2026,1,1), updatedAt: DateTime.utc(2026,1,1),
    ));
    // Android(Client) 已有任务 B
    await clientRepo.upsertTask(Task(
      id: 'B', title: '客户端任务',
      createdAt: DateTime.utc(2026,1,1), updatedAt: DateTime.utc(2026,1,2),
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
      id: 'X', title: '服务端新版',
      createdAt: DateTime.utc(2026,1,1), updatedAt: DateTime.utc(2026,1,3), version: 2, changeId: 'X-v2',
    ));
    await clientRepo.upsertTask(Task(
      id: 'X', title: '客户端旧版',
      createdAt: DateTime.utc(2026,1,1), updatedAt: DateTime.utc(2026,1,2), version: 1, changeId: 'X-v1',
    ));

    final server = SyncServer(serverRepo);
    await server.start();
    final client = SyncClient(Uri.parse('http://127.0.0.1:${server.port}/'));
    try {
      final engine = SyncEngine(clientRepo);
      await runSync(client, engine);
      final merged = (await clientRepo.allTasks()).firstWhere((t) => t.id == 'X');
      expect(merged.title, '服务端新版');
    } finally {
      await server.stop();
    }
  });
}
