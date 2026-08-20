import 'dart:convert';
import 'dart:io';
import '../models/models.dart';
import '../storage/repository.dart';
import 'sync_engine.dart';

/// Windows 端 = Server：常驻监听，提供拉取/接收，带令牌鉴权。
class SyncServer {
  final TaskRepository repo;
  final String token; // 空串表示不鉴权（测试/向后兼容）
  HttpServer? _server;
  int get port => _server?.port ?? 0;
  SyncServer(this.repo, {this.token = ''});

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server!.listen(_handle);
  }

  Future<void> stop() async => _server?.close(force: true);

  bool _authorized(HttpRequest req) {
    if (token.isEmpty) return true;
    final auth = req.headers.value(HttpHeaders.authorizationHeader) ?? '';
    return auth == 'Bearer $token';
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      if (!_authorized(req)) {
        req.response.statusCode = 401;
        await req.response.close();
        return;
      }
      if (req.method == 'GET' && req.uri.path == '/pull') {
        final tasks = await repo.allTasks();
        final lists = await repo.allLists();
        final changes = await repo.changesSince(null);
        final cursor = changes.isEmpty ? '' : changes.last.changeId;
        final body = {
          'tasks': tasks.map((t) => t.toJson()).toList(),
          'lists': lists.map((l) => l.toJson()).toList(),
          'cursor': cursor,
        };
        _json(req, body);
      } else if (req.method == 'POST' && req.uri.path == '/push') {
        final root = jsonDecode(await utf8.decoder.bind(req).join())
            as Map<String, dynamic>;
        final known =
            (await repo.changesSince(null)).map((c) => c.changeId).toSet();
        var applied = 0;
        for (final e in (root['tasks'] as List?) ?? const []) {
          final task = Task.fromJson(e as Map<String, Object?>);
          if (known.contains(task.changeId)) continue;
          await repo.upsertTask(task);
          applied++;
        }
        for (final e in (root['lists'] as List?) ?? const []) {
          final incoming = TaskList.fromJson(e as Map<String, Object?>);
          final existing = (await repo.allLists())
              .where((l) => l.id == incoming.id)
              .toList();
          if (existing.isEmpty ||
              incoming.updatedAt.isAfter(existing.first.updatedAt)) {
            await repo.upsertList(incoming);
          }
        }
        _json(req, {'ok': true, 'applied': applied});
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

/// 一次 /pull 返回的快照。
class SyncSnapshot {
  final List<Task> tasks;
  final List<TaskList> lists;
  final String cursor;
  const SyncSnapshot({
    required this.tasks,
    required this.lists,
    required this.cursor,
  });
}

/// Android 端 = Client：向 Server 拉取/推送（携带令牌）。
class SyncClient {
  final Uri _base;
  final HttpClient _http;
  final String token;
  SyncClient(this._base, {HttpClient? http, this.token = ''})
      : _http = http ?? HttpClient();

  Future<SyncSnapshot> pullSnapshot() async {
    final req = await _http.getUrl(_base.resolve('/pull'));
    if (token.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    final resp = await req.close();
    final body = await utf8.decoder.bind(resp).join();
    if (resp.statusCode != 200) {
      throw StateError('pull failed: ${resp.statusCode}');
    }
    final root = jsonDecode(body) as Map<String, dynamic>;
    final tasks = ((root['tasks'] as List?) ?? const [])
        .map((e) => Task.fromJson(e as Map<String, Object?>))
        .toList();
    final lists = ((root['lists'] as List?) ?? const [])
        .map((e) => TaskList.fromJson(e as Map<String, Object?>))
        .toList();
    return SyncSnapshot(
      tasks: tasks,
      lists: lists,
      cursor: (root['cursor'] as String?) ?? '',
    );
  }

  Future<void> push(List<Task> tasks, List<TaskList> lists) async {
    final req = await _http.postUrl(_base.resolve('/push'));
    req.headers.contentType = ContentType.json;
    if (token.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    req.write(jsonEncode({
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'lists': lists.map((l) => l.toJson()).toList(),
    }));
    final resp = await req.close();
    await utf8.decoder.bind(resp).join();
    if (resp.statusCode != 200) {
      throw StateError('push failed: ${resp.statusCode}');
    }
  }
}

/// 一次完整同步：Client 拉取快照 → SyncEngine 双向合并 → 把需要推送的写回 Server。
Future<void> runSync(SyncClient client, SyncEngine engine) async {
  final snap = await client.pullSnapshot();
  final result = await engine.mergeRemote(
    remoteTasks: snap.tasks,
    seenChangeIds: const [],
    remoteLists: snap.lists,
  );
  if (result.toPush.isNotEmpty || result.listsToPush.isNotEmpty) {
    await client.push(result.toPush, result.listsToPush);
  }
}
