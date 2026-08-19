import 'dart:convert';
import 'dart:io';
import '../models/models.dart';
import 'repository.dart';

/// 基于本地 JSON 文件的持久化仓库（Android/Windows 通用，纯 Dart，可单测）。
/// 数据文件结构：{ "version":1, "tasks":[...], "lists":[...], "changes":[...] }
class FileRepository implements TaskRepository {
  final File file;
  late List<Task> _tasks;
  late List<TaskList> _lists;
  final List<Change> _changes = [];

  FileRepository(this.file, {bool load = true}) {
    _tasks = [];
    _lists = [];
    if (load && file.existsSync()) _loadSync();
  }

  void _loadSync() {
    try {
      final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      _tasks = ((root['tasks'] as List?) ?? const [])
          .map((e) => Task.fromJson(e as Map<String, Object?>))
          .toList();
      _lists = ((root['lists'] as List?) ?? const [])
          .map((e) => TaskList.fromJson(e as Map<String, Object?>))
          .toList();
      final ch = (root['changes'] as List?) ?? const [];
      _changes
        ..clear()
        ..addAll(ch.map((e) => Change(
              changeId: e['changeId'] as String,
              taskId: e['taskId'] as String?,
              kind: e['kind'] as String,
              timestamp: DateTime.parse(e['timestamp'] as String).toUtc(),
              version: (e['version'] as num?)?.toInt() ?? 1,
            )));
    } catch (_) {
      _tasks = [];
      _lists = [];
      _changes.clear();
    }
  }

  Future<void> _persist({
    List<Task>? tasks,
    List<TaskList>? lists,
    List<Change>? changes,
  }) async {
    final root = {
      'version': 1,
      'tasks': (tasks ?? _tasks).map((t) => t.toJson()).toList(),
      'lists': (lists ?? _lists).map((l) => l.toJson()).toList(),
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
  Future<List<TaskList>> allLists() async => List.of(_lists);

  @override
  Future<void> upsertTask(Task task) async {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx >= 0) {
      _tasks[idx] = task;
    } else {
      _tasks.add(task);
    }
    _changes.add(Change(
      changeId: task.changeId,
      taskId: task.id,
      kind: task.deleted ? 'delete' : 'upsert',
      timestamp: task.updatedAt,
      version: task.version,
    ));
    await _persist();
  }

  @override
  Future<void> upsertList(TaskList list) async {
    final idx = _lists.indexWhere((l) => l.id == list.id);
    if (idx >= 0) {
      _lists[idx] = list;
    } else {
      _lists.add(list);
    }
    await _persist();
  }

  @override
  Future<void> replaceTasksAndRemoveList(
      String listId, List<Task> tasks) async {
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
      changes: nextChanges,
    );
    _tasks = nextTasks;
    _lists = nextLists;
    _changes
      ..clear()
      ..addAll(nextChanges);
  }

  @override
  Future<void> removeList(String id) async {
    _lists.removeWhere((list) => list.id == id);
    await _persist();
  }

  @override
  Future<void> removeTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await _persist();
  }

  @override
  Future<List<Change>> changesSince(String? cursor) async {
    final idx = cursor == null
        ? 0
        : _changes.indexWhere((c) => c.changeId == cursor) + 1;
    return idx < 0 ? List.of(_changes) : _changes.skip(idx).toList();
  }
}
