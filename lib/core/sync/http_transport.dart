import 'dart:convert';
import 'dart:io';
import '../models/models.dart';
import '../storage/repository.dart';
import 'conflict_resolver.dart';
import 'sync_engine.dart';

/// Windows 端 = Server：常驻监听，提供拉取/接收，带令牌鉴权。
class SyncServer {
  final TaskRepository repo;
  final String token;
  HttpServer? _server;
  int get port => _server?.port ?? 0;
  SyncServer(this.repo, {this.token = ''});

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server!.listen(_handle);
  }

  Future<void> stop() async => _server?.close(force: true);

  bool _authorized(HttpRequest req) {
    if (token.isEmpty) return false;
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
        final after = req.uri.queryParameters['after'];
        final changes = await repo
            .changesSince(after == null || after.isEmpty ? null : after);
        final allTasks = await repo.allTasks();
        final allTombstones = await repo.allTombstones();
        final changedTaskIds =
            changes.map((change) => change.taskId).whereType<String>().toSet();
        final tasks = after == null || after.isEmpty
            ? allTasks
            : allTasks
                .where((task) => changedTaskIds.contains(task.id))
                .toList();
        final tombstones = after == null || after.isEmpty
            ? allTombstones
            : allTombstones
                .where((tombstone) => changedTaskIds.contains(tombstone.id))
                .toList();
        final lists = await repo.allLists(includeDeleted: true);
        final cursor = changes.isEmpty ? (after ?? '') : changes.last.changeId;
        final knownChangeIds =
            (await repo.changesSince(null)).map((change) => change.changeId);
        final body = {
          'tasks': tasks.map((t) => t.toJson()).toList(),
          'tombstones': tombstones.map((t) => t.toJson()).toList(),
          'lists': lists.map((l) => l.toJson()).toList(),
          'cursor': cursor,
          'knownChangeIds': knownChangeIds.toList(),
        };
        _json(req, body);
      } else if (req.method == 'POST' && req.uri.path == '/push') {
        final root = jsonDecode(await utf8.decoder.bind(req).join())
            as Map<String, dynamic>;
        final known =
            (await repo.changesSince(null)).map((c) => c.changeId).toSet();
        var applied = 0;
        var rejected = 0;
        final rejectedIds = <String>[];
        for (final e in (root['tasks'] as List?) ?? const []) {
          final task = Task.fromJson(e as Map<String, Object?>);
          if (known.contains(task.changeId)) continue;
          final matches = (await repo.allTasks())
              .where((candidate) => candidate.id == task.id)
              .toList();
          final existing = matches.isEmpty ? null : matches.first;
          final tombstoneMatches = (await repo.allTombstones())
              .where((candidate) => candidate.id == task.id)
              .toList();
          final tombstone =
              tombstoneMatches.isEmpty ? null : tombstoneMatches.first;
          if (tombstone != null && compareTaskTombstone(task, tombstone) <= 0) {
            rejected++;
            rejectedIds.add(task.changeId);
            continue;
          }
          if (existing != null && compareLatest(existing, task) >= 0) {
            rejected++;
            rejectedIds.add(task.changeId);
            continue;
          }
          await repo.upsertTask(task);
          known.add(task.changeId);
          applied++;
        }
        for (final e in (root['tombstones'] as List?) ?? const []) {
          final incoming = TaskTombstone.fromJson(e as Map<String, Object?>);
          final existingTask = (await repo.allTasks())
              .where((candidate) => candidate.id == incoming.id)
              .toList();
          final task = existingTask.isEmpty ? null : existingTask.first;
          final existingTombstone = (await repo.allTombstones())
              .where((candidate) => candidate.id == incoming.id)
              .toList();
          if (task != null && compareTaskTombstone(task, incoming) >= 0) {
            rejected++;
            rejectedIds.add(incoming.changeId);
            continue;
          }
          if (existingTombstone.isNotEmpty &&
              compareTombstone(existingTombstone.first, incoming) >= 0) {
            rejected++;
            rejectedIds.add(incoming.changeId);
            continue;
          }
          await repo.upsertTombstone(incoming);
          known.add(incoming.changeId);
          applied++;
        }
        for (final e in (root['lists'] as List?) ?? const []) {
          final incoming = TaskList.fromJson(e as Map<String, Object?>);
          final existing = (await repo.allLists(includeDeleted: true))
              .where((l) => l.id == incoming.id)
              .toList();
          if (existing.isEmpty ||
              compareListLatest(incoming, existing.first) > 0) {
            await repo.upsertList(incoming);
          }
        }
        _json(req, {
          'ok': true,
          'applied': applied,
          'rejected': rejected,
          'rejectedChangeIds': rejectedIds,
        });
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
  final List<TaskTombstone> tombstones;
  final List<TaskList> lists;
  final String cursor;
  final List<String> knownChangeIds;
  const SyncSnapshot({
    required this.tasks,
    this.tombstones = const [],
    required this.lists,
    required this.cursor,
    this.knownChangeIds = const [],
  });
}

/// Server response for one push operation.
class PushResult {
  final int applied;
  final int rejected;
  final List<String> rejectedChangeIds;

  const PushResult({
    required this.applied,
    required this.rejected,
    required this.rejectedChangeIds,
  });
}

/// Android 端 = Client：向 Server 拉取/推送（携带令牌）。
class SyncClient {
  final Uri _base;
  final HttpClient _http;
  final String token;
  SyncClient(this._base, {HttpClient? http, this.token = ''})
      : _http = http ?? HttpClient();

  Future<SyncSnapshot> pullSnapshot({String? after}) async {
    final uri = _base.resolve('/pull').replace(
          queryParameters: after == null ? null : {'after': after},
        );
    final req = await _http.getUrl(uri);
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
    final tombstones = ((root['tombstones'] as List?) ?? const [])
        .map((e) => TaskTombstone.fromJson(e as Map<String, Object?>))
        .toList();
    final lists = ((root['lists'] as List?) ?? const [])
        .map((e) => TaskList.fromJson(e as Map<String, Object?>))
        .toList();
    return SyncSnapshot(
      tasks: tasks,
      tombstones: tombstones,
      lists: lists,
      cursor: (root['cursor'] as String?) ?? '',
      knownChangeIds: ((root['knownChangeIds'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  Future<PushResult> push(List<Task> tasks, List<TaskList> lists,
      {List<TaskTombstone> tombstones = const []}) async {
    final req = await _http.postUrl(_base.resolve('/push'));
    req.headers.contentType = ContentType.json;
    if (token.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    req.write(jsonEncode({
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'tombstones': tombstones.map((t) => t.toJson()).toList(),
      'lists': lists.map((l) => l.toJson()).toList(),
    }));
    final resp = await req.close();
    final body = await utf8.decoder.bind(resp).join();
    if (resp.statusCode != 200) {
      throw StateError('push failed: ${resp.statusCode}');
    }
    final root = jsonDecode(body) as Map<String, dynamic>;
    return PushResult(
      applied: (root['applied'] as num?)?.toInt() ?? 0,
      rejected: (root['rejected'] as num?)?.toInt() ?? 0,
      rejectedChangeIds: ((root['rejectedChangeIds'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

/// 一次完整同步：Client 拉取快照 → SyncEngine 双向合并 → 把需要推送的写回 Server。
Future<void> runSync(SyncClient client, SyncEngine engine,
    {String? after,
    Future<void> Function(String cursor)? onCursorCommitted}) async {
  final snap = await client.pullSnapshot(after: after);
  final result = await engine.mergeRemote(
    remoteTasks: snap.tasks,
    remoteTombstones: snap.tombstones,
    seenChangeIds: snap.knownChangeIds,
    remoteLists: snap.lists,
    remoteSnapshotComplete: after == null || after.isEmpty,
  );
  if (result.toPush.isNotEmpty ||
      result.listsToPush.isNotEmpty ||
      result.tombstonesToPush.isNotEmpty) {
    final pushResult = await client.push(result.toPush, result.listsToPush,
        tombstones: result.tombstonesToPush);
    if (pushResult.rejectedChangeIds.isNotEmpty) {
      throw StateError('同步时远端拒绝了 ${pushResult.rejectedChangeIds.length} 条本地变更');
    }
  }
  await onCursorCommitted?.call(snap.cursor);
}
