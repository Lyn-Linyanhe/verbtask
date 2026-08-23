import 'package:uuid/uuid.dart';

final _listChangeUuid = Uuid();

/// 清单（Lists）。收件箱用 listId == null 表达，不单独建表。
class TaskList {
  final String id;
  final String name;
  final String? color;
  final int sortOrder;
  final DateTime updatedAt;
  final int version;
  final String changeId;
  final bool deleted;

  const TaskList({
    required this.id,
    required this.name,
    this.color,
    this.sortOrder = 0,
    required this.updatedAt,
    this.version = 1,
    String? changeId,
    this.deleted = false,
  }) : changeId = changeId ?? '$id-v$version';

  TaskList copyWith({
    String? name,
    String? color,
    int? sortOrder,
    bool? deleted,
  }) =>
      TaskList(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        sortOrder: sortOrder ?? this.sortOrder,
        updatedAt: DateTime.now().toUtc(),
        version: version + 1,
        changeId: _listChangeUuid.v4(),
        deleted: deleted ?? this.deleted,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'sortOrder': sortOrder,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'version': version,
        'changeId': changeId,
        'deleted': deleted,
      };

  factory TaskList.fromJson(Map<String, Object?> json) => TaskList(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
        version: (json['version'] as num?)?.toInt() ?? 1,
        changeId: json['changeId'] as String?,
        deleted: (json['deleted'] as bool?) ?? false,
      );
}
