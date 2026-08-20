import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
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
    await widget.service.edit(widget.task,
        title: _title.text.trim(),
        notes: _notes.text.trim(),
        status: _status,
        rrule: rr.isEmpty ? null : rr);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.editTask)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
              child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionLabel(l.basicInformation),
              const SizedBox(height: 10),
              TextField(
                  controller: _title,
                  decoration: InputDecoration(labelText: l.titleField)),
              const SizedBox(height: 14),
              TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: l.notesField)),
              const SizedBox(height: 14),
              DropdownButtonFormField<TaskStatus>(
                initialValue: _status,
                decoration: InputDecoration(labelText: l.statusField),
                items: TaskStatus.values
                    .map((s) => DropdownMenuItem(
                        value: s, child: Text(_statusLabel(s, l))))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            ]),
          )),
          const SizedBox(height: 14),
          Card(
              child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionLabel(l.scheduling),
              const SizedBox(height: 10),
              TextField(
                  controller: _rrule,
                  decoration: InputDecoration(
                      labelText: l.repeatRule, hintText: l.repeatRuleHint)),
            ]),
          )),
          const SizedBox(height: 26),
          FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: Text(l.save)),
        ],
      ),
    );
  }

  String _statusLabel(TaskStatus s, AppLocalizations l) => switch (s) {
        TaskStatus.todo => l.todo,
        TaskStatus.doing => l.doing,
        TaskStatus.done => l.done,
      };
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant));
}
