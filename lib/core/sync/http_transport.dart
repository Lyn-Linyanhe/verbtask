import 'dart:convert';
import 'dart:io';
import '../models/models.dart';
import '../storage/repository.dart';
import 'sync_engine.dart';

/// Windows 端 = Server：常驻监听，提供拉取/接收。
class SyncServer {
  final TaskRepository repo;
  HttpServer? _server;
  int get port => _server?.port ?? 0;
  SyncServer(this.repo);

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server!.listen(_handle);
  }

  Future<void> stop() async => _server?.close(force: true);

  Future<void> _handle(HttpRequest req) async {
    try {
      if (req.method == 'GET' && req.uri.path == '/pull') {
        final tasks = await repo.allTasks();
        _json(req, {'tasks': tasks.map((t) => t.toJson()).toList()});
      } else if (req.method == 'POST' && req.uri.path == '/push') {
        final body = jsonDecode(await utf8.decoder.bind(req).join());
        final list = (body['tasks'] as List?) ?? const [];
        for (final e in list) {
          await repo.upsertTask(Task.fromJson(e as Map<String, Object?>));
        }
        _json(req, {'ok': true});
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    } catch (_) {
      req.response.statusCode = 500;
      await req.response.close();
    }
  }

  void _json(HttpRequest req, Object data) {
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(data));
    req.response.close();
  }
}

/// Android 端 = Client：向 Server 拉取/推送。
class SyncClient {
  final Uri _base;
  final HttpClient _http;
  SyncClient(this._base, {HttpClient? http}) : _http = http ?? HttpClient();

  Future<List<Task>> pull() async {
    final req = await _http.getUrl(_base.resolve('/pull'));
    final resp = await req.close();
    final body = await utf8.decoder.bind(resp).join();
    if (resp.statusCode != 200) throw StateError('pull failed: ${resp.statusCode}');
    final root = jsonDecode(body) as Map<String, dynamic>;
    return ((root['tasks'] as List?) ?? const [])
        .map((e) => Task.fromJson(e as Map<String, Object?>))
        .toList();
  }

  Future<void> push(List<Task> tasks) async {
    final req = await _http.postUrl(_base.resolve('/push'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'tasks': tasks.map((t) => t.toJson()).toList()}));
    final resp = await req.close();
    await utf8.decoder.bind(resp).join();
    if (resp.statusCode != 200) throw StateError('push failed: ${resp.statusCode}');
  }
}

/// 一次完整同步：Client 从 Server 拉取 → 用 SyncEngine 合并 → 把需要推送的写回 Server。
Future<void> runSync(SyncClient client, SyncEngine engine) async {
  final remote = await client.pull();
  final seen = <String>[]; // v0：全量拉取，幂等由 changeId 去重保证
  final result = await engine.mergeRemote(remoteTasks: remote, seenChangeIds: seen);
  if (result.toPush.isNotEmpty) {
    await client.push(result.toPush);
  }
}
