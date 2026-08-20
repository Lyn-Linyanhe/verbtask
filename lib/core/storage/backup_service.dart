import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'repository.dart';

const _uuid = Uuid();

/// 备份 / 导出 / 导入。JSON 是完整保真格式；CSV 面向表格工具与迁移。
class BackupService {
  final TaskRepository _repo;
  const BackupService(this._repo);

  static const _csvHeader = [
    'id',
    'title',
    'notes',
    'listId',
    'status',
    'due',
    'dateOnly',
    'priority',
    'rrule',
    'deleted',
  ];

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
  /// 返回导入的任务数。版本不支持的备份在写入前即拒绝。
  Future<int> importJson(String json) async {
    final root = jsonDecode(json) as Map<String, dynamic>;
    if (root['format'] != 'verb-app') {
      throw const FormatException('不是 verb-app 备份文件');
    }
    final version = (root['version'] as num?)?.toInt() ?? 1;
    if (version != 1) {
      throw FormatException('不支持的备份版本: $version');
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

  /// 导出为 CSV（含表头）。列表不随 CSV 导出，listId 保留原值。
  Future<String> exportCsv() async {
    final tasks = await _repo.allTasks();
    final rows = <List<String>>[_csvHeader];
    for (final t in tasks) {
      rows.add([
        t.id,
        t.title,
        t.notes,
        t.listId ?? '',
        t.status.name,
        t.due?.value.toIso8601String() ?? '',
        (t.due?.dateOnly ?? false).toString(),
        t.priority.toString(),
        t.rrule ?? '',
        t.deleted.toString(),
      ]);
    }
    return rows.map((fields) => fields.map(_csvField).join(',')).join('\n');
  }

  /// 导入 CSV。表头必须匹配；空 id 会生成新 id。返回导入的任务数。
  Future<int> importCsv(String csv) async {
    final rows = _parseCsv(csv);
    if (rows.isEmpty) return 0;
    final header = rows.first.map((e) => e.trim()).toList();
    if (header.length != _csvHeader.length ||
        !List.generate(_csvHeader.length, (i) => header[i] == _csvHeader[i])
            .every((ok) => ok)) {
      throw const FormatException('CSV 表头不匹配');
    }
    final idx = {for (var i = 0; i < header.length; i++) header[i]: i};
    String field(List<String> row, String name) => row[idx[name]!].trim();

    var count = 0;
    final now = DateTime.now().toUtc();
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.length < header.length) continue;
      final dueRaw = field(row, 'due');
      final due = dueRaw.isEmpty
          ? null
          : DueDate(
              DateTime.parse(dueRaw).toUtc(),
              dateOnly: field(row, 'dateOnly') == 'true',
            );
      final idRaw = field(row, 'id');
      final task = Task(
        id: idRaw.isEmpty ? _uuid.v4() : idRaw,
        title: field(row, 'title'),
        notes: field(row, 'notes'),
        listId: field(row, 'listId').isEmpty ? null : field(row, 'listId'),
        status: TaskStatus.values.firstWhere(
          (e) => e.name == field(row, 'status'),
          orElse: () => TaskStatus.todo,
        ),
        due: due,
        priority: int.tryParse(field(row, 'priority')) ?? 0,
        rrule: field(row, 'rrule').isEmpty ? null : field(row, 'rrule'),
        deleted: field(row, 'deleted') == 'true',
        createdAt: now,
        updatedAt: now,
      );
      await _repo.upsertTask(task);
      count++;
    }
    return count;
  }

  String _csvField(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  List<List<String>> _parseCsv(String csv) {
    final rows = <List<String>>[];
    final current = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var i = 0;
    while (i < csv.length) {
      final ch = csv[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < csv.length && csv[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        current.add(field.toString());
        field.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < csv.length && csv[i + 1] == '\n') i++;
        current.add(field.toString());
        field.clear();
        if (current.isNotEmpty) {
          rows.add(List.of(current));
          current.clear();
        }
      } else {
        field.write(ch);
      }
      i++;
    }
    if (field.isNotEmpty || current.isNotEmpty) {
      current.add(field.toString());
      rows.add(current);
    }
    return rows;
  }
}
