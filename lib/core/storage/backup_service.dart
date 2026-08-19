import 'dart:convert';
import '../models/models.dart';
import 'repository.dart';

/// 备份 / 导出 / 导入。数据以 JSON 序列化，本地文件可带走、可恢复。
class BackupService {
  final TaskRepository _repo;
  const BackupService(this._repo);

  Future<String> exportJson() async {
    final tasks = await _repo.allTasks();
    final lists = await _repo.allLists();
    return jsonEncode({
      'format': 'verb-app',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'lists': lists.map((l) => l.toJson()).toList(),
    });
  }

  /// 导入：解析后逐条 upsert（保留各自 id/version/changeId，避免覆盖破坏引用）。
  /// 返回导入的任务数。
  Future<int> importJson(String json) async {
    final root = jsonDecode(json) as Map<String, dynamic>;
    if (root['format'] != 'verb-app') {
      throw const FormatException('不是 verb-app 备份文件');
    }
    final lists = (root['lists'] as List?) ?? const [];
    for (final e in lists) {
      await _repo.upsertList(TaskList.fromJson(e as Map<String, Object?>));
    }
    final tasks = (root['tasks'] as List?) ?? const [];
    for (final e in tasks) {
      await _repo.upsertTask(Task.fromJson(e as Map<String, Object?>));
    }
    return tasks.length;
  }
}
