import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/task_service.dart';

class TaskEditPage extends StatefulWidget {
  final Task task;
  final TaskService service;
  const TaskEditPage({super.key, required this.task, required this.service});

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _rrule;
  TaskStatus _status = TaskStatus.todo;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task.title);
    _notes = TextEditingController(text: widget.task.notes);
    _rrule = TextEditingController(text: widget.task.rrule ?? '');
    _status = widget.task.status;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _rrule.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rr = _rrule.text.trim();
    await widget.service.edit(
      widget.task,
      title: _title.text.trim(),
      notes: _notes.text.trim(),
      status: _status,
      rrule: rr.isEmpty ? null : rr,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑任务')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: '标题', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: '备注', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<TaskStatus>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: '状态', border: OutlineInputBorder()),
            items: TaskStatus.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 12),
          TextField(controller: _rrule, decoration: const InputDecoration(labelText: '重复规则 (RRULE)', hintText: 'FREQ=DAILY', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
