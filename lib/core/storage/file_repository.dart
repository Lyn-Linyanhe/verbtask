import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/models.dart';
import '../sync/conflict_resolver.dart';
import 'repository.dart';

export 'repository.dart' show StorageLoadException;

/// 基于本地 JSON 文件的持久化仓库（Android/Windows 通用，纯 Dart，可单测）。
/// 数据文件结构：{ "version":2, "tasks":[...], "lists":[...],
/// "tombstones":[...], "changes":[...] }
class FileRepository implements TaskRepository {
  static const currentSchemaVersion = TaskRepository.currentSchemaVersion;
  final File file;
  late List<Task> _tasks;
  late List<TaskList> _lists;
  late List<TaskTombstone> _tombstones;
  final List<Change> _changes = [];
  Future<void> _writeTail = Future<void>.value();

  FileRepository(this.file, {bool load = true}) {
    _tasks = [];
    _lists = [];
    _tombstones = [];
    if (load && file.existsSync()) _loadSync();
  }

  void _loadSync() {
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        throw const FormatException('数据根节点必须是对象');
      }
      final root = _migrateRoot(Map<String, Object?>.from(decoded));
      final tasks = ((root['tasks'] as List?) ?? const [])
          .map((e) => Task.fromJson(e as Map<String, Object?>))
          .toList();
      final lists = ((root['lists'] as List?) ?? const [])
          .map((e) => TaskList.fromJson(e as Map<String, Object?>))
          .toList();
      final tombstones = ((root['tombstones'] as List?) ?? const [])
          .map((e) => TaskTombstone.fromJson(e as Map<String, Object?>))
          .toList();
      final ch = (root['changes'] as List?) ?? const [];
      final changes = ch.map((e) {
        final item = e as Map<String, Object?>;
        return Change(
          changeId: item['changeId'] as String,
          taskId: item['taskId'] as String?,
          kind: item['kind'] as String,
          timestamp: DateTime.parse(item['timestamp'] as String).toUtc(),
          version: (item['version'] as num?)?.toInt() ?? 1,
        );
      }).toList();
      _tasks = tasks;
      _lists = lists;
      _tombstones = tombstones;
      _changes
        ..clear()
        ..addAll(changes);
    } catch (error) {
      final recoveryPath = _copyForRecovery();
      throw StorageLoadException(
        filePath: file.path,
        recoveryPath: recoveryPath,
        cause: error,
      );
    }
  }

  Map<String, Object?> _migrateRoot(Map<String, Object?> root) {
    final rawVersion = root['version'];
    final version = rawVersion is num ? rawVersion.toInt() : 1;
    if (version > currentSchemaVersion) {
      throw FormatException('不支持的数据版本: $version');
    }
    if (version < 1) {
      throw FormatException('无效的数据版本: $version');
    }

    // v1 与 v2 的记录格式兼容；显式补齐 schema 版本，方便后续迁移继续演进。
    final migrated = Map<String, Object?>.from(root);
    migrated['version'] = currentSchemaVersion;
    migrated['tasks'] ??= const <Object?>[];
    migrated['lists'] ??= const <Object?>[];
    migrated['changes'] ??= const <Object?>[];
    migrated['tombstones'] ??= const <Object?>[];
    if (migrated['tasks'] is! List ||
        migrated['lists'] is! List ||
        migrated['tombstones'] is! List ||
        migrated['changes'] is! List) {
      throw const FormatException('数据记录必须是数组');
    }
    return migrated;
  }

  String? _copyForRecovery() {
    if (!file.existsSync()) return null;
    final path =
        '${file.path}.corrupt-${DateTime.now().microsecondsSinceEpoch}';
    try {
      file.copySync(path);
      return path;
    } catch (_) {
      return null;
    }
  }

  /// 串行化“计算快照 → 原子替换 → 提交内存状态”，避免并发调用基于
  /// 同一旧快照写入固定临时文件而互相覆盖。文件锁和写前重载还覆盖
  /// WorkManager/前台等不同 isolate 创建的仓库实例。
  Future<T> _withWriteLock<T>(Future<T> Function() action) {
    final previous = _writeTail;
    final gate = Completer<void>();
    _writeTail = gate.future;
    return () async {
      try {
        await previous.catchError((_) {});
        return await _withFileLock(() async {
          _reloadLatestSnapshot();
          return action();
        });
      } finally {
        if (!gate.isCompleted) gate.complete();
      }
    }();
  }

  Future<T> _withFileLock<T>(Future<T> Function() action) async {
    final lockFile = File('${file.path}.lock');
    await lockFile.parent.create(recursive: true);
    final handle = await lockFile.open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      return await action();
    } finally {
      try {
        await handle.unlock();
      } finally {
        await handle.close();
      }
    }
  }

  void _reloadLatestSnapshot() {
    if (!file.existsSync()) {
      _tasks = [];
      _lists = [];
      _tombstones = [];
      _changes.clear();
      return;
    }
    final latest = FileRepository(file);
    _tasks = List.of(latest._tasks);
    _lists = List.of(latest._lists);
    _tombstones = List.of(latest._tombstones);
    _changes
      ..clear()
      ..addAll(latest._changes);
  }

  Future<void> _persist({
    List<Task>? tasks,
    List<TaskList>? lists,
    List<TaskTombstone>? tombstones,
    List<Change>? changes,
  }) async {
    final root = {
      'version': currentSchemaVersion,
      'tasks': (tasks ?? _tasks).map((t) => t.toJson()).toList(),
      'lists': (lists ?? _lists).map((l) => l.toJson()).toList(),
      'tombstones': (tombstones ?? _tombstones).map((t) => t.toJson()).toList(),
      'changes': (changes ?? _changes)
          .map((c) => {
                'changeId': c.changeId,
                'taskId': c.taskId,
                'kind': c.kind,
                'timestamp': c.timestamp.toIso8601String(),
                'version': c.version,
              })
          .toList(),
    };
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsString(jsonEncode(root), flush: true);
      await temp.rename(file.path);
    } catch (_) {
      // 原文件只在临时文件完整写入后才会被替换；失败时保留原数据。
      if (await temp.exists()) {
        await temp.delete();
      }
      rethrow;
    }
  }

  @override
  Future<List<Task>> allTasks() async => List.of(_tasks);

  @override
  @override
  Future<List<TaskList>> allLists({bool includeDeleted = false}) async =>
      List.of(_lists.where((list) => includeDeleted || !list.deleted));

  @override
  Future<List<TaskTombstone>> allTombstones() async => List.of(_tombstones);

  @override
  Future<void> upsertTask(Task task) async {
    await _withWriteLock(() async {
      final tombstone = _tombstones
          .where((candidate) => candidate.id == task.id)
          .cast<TaskTombstone?>()
          .firstWhere((candidate) => candidate != null, orElse: () => null);
      if (tombstone != null && compareTaskTombstone(task, tombstone) <= 0) {
        // 旧编辑页或旧设备的数据不能穿过永久删除墓碑复活任务。
        return;
      }
      final nextTasks = List<Task>.of(_tasks);
      final idx = nextTasks.indexWhere((t) => t.id == task.id);
      if (idx >= 0) {
        nextTasks[idx] = task;
      } else {
        nextTasks.add(task);
      }
      final nextTombstones = _tombstones.where((t) => t.id != task.id).toList();
      final nextChanges = List<Change>.of(_changes)
        ..add(Change(
          changeId: task.changeId,
          taskId: task.id,
          kind: task.deleted ? 'delete' : 'upsert',
          timestamp: task.updatedAt,
          version: task.version,
        ));
      await _persist(
          tasks: nextTasks, tombstones: nextTombstones, changes: nextChanges);
      _tasks = nextTasks;
      _tombstones = nextTombstones;
      _changes
        ..clear()
        ..addAll(nextChanges);
    });
  }

  @override
  Future<void> upsertList(TaskList list) async {
    await _withWriteLock(() async {
      final nextLists = List<TaskList>.of(_lists);
      final idx = nextLists.indexWhere((l) => l.id == list.id);
      if (idx >= 0) {
        nextLists[idx] = list;
      } else {
        nextLists.add(list);
      }
      await _persist(lists: nextLists);
      _lists = nextLists;
    });
  }

  @override
  Future<void> upsertTombstone(TaskTombstone tombstone) async {
    await _withWriteLock(() async {
      final matches = _tombstones
          .where((candidate) => candidate.id == tombstone.id)
          .toList();
      final existing = matches.isEmpty ? null : matches.first;
      if (existing != null && compareTombstone(existing, tombstone) >= 0) {
        return;
      }
      final nextTasks =
          _tasks.where((task) => task.id != tombstone.id).toList();
      final nextTombstones = _tombstones
          .where((candidate) => candidate.id != tombstone.id)
          .toList()
        ..add(tombstone);
      final nextChanges = List<Change>.of(_changes)
        ..add(Change(
          changeId: tombstone.changeId,
          taskId: tombstone.id,
          kind: 'delete',
          timestamp: tombstone.updatedAt,
          version: tombstone.version,
        ));
      await _persist(
        tasks: nextTasks,
        tombstones: nextTombstones,
        changes: nextChanges,
      );
      _tasks = nextTasks;
      _tombstones = nextTombstones;
      _changes
        ..clear()
        ..addAll(nextChanges);
    });
  }

  @override
  Future<void> replaceSnapshot({
    required List<Task> tasks,
    required List<TaskList> lists,
    Iterable<Change> changes = const [],
    Iterable<TaskTombstone> tombstones = const [],
  }) async {
    await _withWriteLock(() async {
      final nextTasks = List<Task>.of(tasks);
      final nextLists = List<TaskList>.of(lists);
      final nextTombstones = List<TaskTombstone>.of(tombstones);
      final nextChanges = List<Change>.of(_changes);
      final known = nextChanges.map((change) => change.changeId).toSet();
      for (final change in changes) {
        if (known.add(change.changeId)) nextChanges.add(change);
      }
      await _persist(
        tasks: nextTasks,
        lists: nextLists,
        tombstones: nextTombstones,
        changes: nextChanges,
      );
      _tasks = nextTasks;
      _lists = nextLists;
      _tombstones = nextTombstones;
      _changes
        ..clear()
        ..addAll(nextChanges);
    });
  }

  @override
  Future<void> replaceTasksAndRemoveList(
      String listId, List<Task> tasks) async {
    await _withWriteLock(() async {
      final nextTasks = List<Task>.of(_tasks);
      final nextChanges = List<Change>.of(_changes);
      for (final task in tasks) {
        final idx = nextTasks.indexWhere((existing) => existing.id == task.id);
        if (idx >= 0) {
          nextTasks[idx] = task;
        } else {
          nextTasks.add(task);
        }
        nextChanges.add(Change(
          changeId: task.changeId,
          taskId: task.id,
          kind: task.deleted ? 'delete' : 'upsert',
          timestamp: task.updatedAt,
          version: task.version,
        ));
      }
      final nextLists = _lists.where((list) => list.id != listId).toList();

      // 只有快照成功替换后才提交内存状态，失败时调用方仍看到完整旧状态。
      await _persist(
        tasks: nextTasks,
        lists: nextLists,
        tombstones: _tombstones,
        changes: nextChanges,
      );
      _tasks = nextTasks;
      _lists = nextLists;
      _changes
        ..clear()
        ..addAll(nextChanges);
    });
  }

  @override
  Future<void> removeList(String id) async {
    await _withWriteLock(() async {
      final nextLists = _lists.where((list) => list.id != id).toList();
      await _persist(lists: nextLists, tombstones: _tombstones);
      _lists = nextLists;
    });
  }

  @override
  Future<void> removeTask(String id) async {
    await _withWriteLock(() async {
      final nextTasks = _tasks.where((task) => task.id != id).toList();
      await _persist(tasks: nextTasks, tombstones: _tombstones);
      _tasks = nextTasks;
    });
  }

  @override
  Future<List<Change>> changesSince(String? cursor) async {
    final idx = cursor == null
        ? 0
        : _changes.indexWhere((c) => c.changeId == cursor) + 1;
    return idx < 0 ? List.of(_changes) : _changes.skip(idx).toList();
  }
}
