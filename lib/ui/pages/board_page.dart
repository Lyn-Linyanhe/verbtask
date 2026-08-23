import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/task_service.dart';
import '../../l10n/generated/app_localizations.dart';

class BoardPage extends StatefulWidget {
  final TaskService service;
  final Future<void> Function()? onTaskChanged;
  const BoardPage({
    super.key,
    required this.service,
    this.onTaskChanged,
  });

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  List<Task> _tasks = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final tasks = await widget.service.query(
      includeDeleted: false,
      includeDone: true,
      by: BySort.dueAsc,
    );
    if (!mounted) return;
    setState(() => _tasks = tasks);
  }

  Future<void> _move(Task task, TaskStatus status) async {
    if (task.status == status) return;
    await widget.service.edit(task, status: status);
    await widget.onTaskChanged?.call();
    await _reload();
  }

  String _statusLabel(TaskStatus status, AppLocalizations l) =>
      switch (status) {
        TaskStatus.todo => l.todo,
        TaskStatus.doing => l.doing,
        TaskStatus.done => l.done,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final statuses = TaskStatus.values;
    return Scaffold(
      appBar: AppBar(title: Text(l.board)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const columnWidth = 280.0;
          const gap = 12.0;
          final boardWidth = (columnWidth + gap) * statuses.length + 16;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
            child: SizedBox(
              width: boardWidth > constraints.maxWidth
                  ? boardWidth
                  : constraints.maxWidth,
              height: constraints.maxHeight - 32,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < statuses.length; index++) ...[
                    if (index > 0) const SizedBox(width: gap),
                    _BoardColumn(
                      width: columnWidth,
                      status: statuses[index],
                      label: _statusLabel(statuses[index], l),
                      tasks: _tasks
                          .where((task) => task.status == statuses[index])
                          .toList(),
                      l: l,
                      onMove: _move,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BoardColumn extends StatelessWidget {
  final double width;
  final TaskStatus status;
  final String label;
  final List<Task> tasks;
  final AppLocalizations l;
  final Future<void> Function(Task, TaskStatus) onMove;

  const _BoardColumn({
    required this.width,
    required this.status,
    required this.label,
    required this.tasks,
    required this.l,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) => d.data.status != status,
      onAcceptWithDetails: (d) => onMove(d.data, status),
      builder: (context, candidates, rejected) => Container(
        width: width,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border.all(
              color: candidates.isNotEmpty
                  ? scheme.primary
                  : scheme.outlineVariant,
              width: candidates.isNotEmpty ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Text('${tasks.length}',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text(l.none,
                          style: TextStyle(color: scheme.onSurfaceVariant)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => Draggable<Task>(
                        data: tasks[index],
                        feedback: Material(
                          color: Colors.transparent,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Text(tasks[index].title,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.4,
                          child: _BoardTask(
                            task: tasks[index],
                            l: l,
                            onMove: onMove,
                          ),
                        ),
                        child: _BoardTask(
                          task: tasks[index],
                          l: l,
                          onMove: onMove,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardTask extends StatelessWidget {
  final Task task;
  final AppLocalizations l;
  final Future<void> Function(Task, TaskStatus) onMove;

  String _priorityBadgeLabel(int priority, AppLocalizations l) =>
      switch (priority) {
        3 => l.priorityHigh,
        2 => l.priorityMedium,
        1 => l.priorityLow,
        _ => '',
      };

  Color _priorityBadgeColor(int priority, ColorScheme scheme) =>
      switch (priority) {
        3 => scheme.error,
        2 => Colors.orange.shade700,
        _ => scheme.onSurfaceVariant,
      };

  const _BoardTask({
    required this.task,
    required this.l,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (task.due != null) ...[
                    const SizedBox(height: 5),
                    Text(_fmtDue(task.due!, l),
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            if (task.priority > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Tooltip(
                  message: _priorityBadgeLabel(task.priority, l),
                  child: Icon(Icons.flag_rounded,
                      size: 15,
                      color: _priorityBadgeColor(task.priority, scheme)),
                ),
              ),
            PopupMenuButton<TaskStatus>(
              tooltip: l.statusField,
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onSelected: (status) => onMove(task, status),
              itemBuilder: (_) => [
                PopupMenuItem(value: TaskStatus.todo, child: Text(l.todo)),
                PopupMenuItem(value: TaskStatus.doing, child: Text(l.doing)),
                PopupMenuItem(value: TaskStatus.done, child: Text(l.done)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtDue(DueDate due, AppLocalizations l) {
  final d = due.dateOnly ? due.value.toUtc() : due.value.toLocal();
  final date = l.dateMonthDay(d.day, d.month);
  if (due.dateOnly) return date;
  final h = d.hour.toString().padLeft(2, '0');
  final minute = d.minute.toString().padLeft(2, '0');
  return '$date $h:$minute';
}
