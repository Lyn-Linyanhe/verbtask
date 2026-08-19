/// 清单（Lists）。收件箱用 listId == null 表达，不单独建表。
class TaskList {
  final String id;
  final String name;
  final String? color;
  final int sortOrder;
  final DateTime updatedAt;

  const TaskList({
    required this.id,
    required this.name,
    this.color,
    this.sortOrder = 0,
    required this.updatedAt,
  });

  TaskList copyWith({String? name, String? color, int? sortOrder}) => TaskList(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        sortOrder: sortOrder ?? this.sortOrder,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'sortOrder': sortOrder,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory TaskList.fromJson(Map<String, Object?> json) => TaskList(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        updatedAt:
            DateTime.parse(json['updatedAt'] as String).toUtc(),
      );
}

