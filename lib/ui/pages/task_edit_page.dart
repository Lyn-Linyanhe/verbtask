import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/models/models.dart';
import '../../core/services/task_service.dart';
import '../../core/notifications/app_notifications.dart';

class TaskEditPage extends StatefulWidget {
  final Task task;
  final TaskService service;
  final List<TaskList> lists;
  final DateTime? occurrence;

  const TaskEditPage({
    super.key,
    required this.task,
    required this.service,
    this.lists = const [],
    this.occurrence,
  });

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  static const _inboxValue = '__inbox__';

  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _rrule;
  late final TextEditingController _reminderOffset;
  late final FocusNode _titleFocus;
  TaskStatus _status = TaskStatus.todo;
  DueDate? _due;
  bool _dateOnly = true;
  bool _reminderEnabled = false;
  ReminderPolicy _reminderPolicy = ReminderPolicy.inherit;
  int _priority = 0;
  String? _listId;

  @override
  void initState() {
    super.initState();
    final override = widget.occurrence == null
        ? null
        : widget.task.overrideFor(widget.occurrence!);
    final sourceReminders = override?.reminders ?? widget.task.reminders;
    final reminder = sourceReminders.isEmpty ? null : sourceReminders.first;
    _title = TextEditingController(text: override?.title ?? widget.task.title);
    _titleFocus = FocusNode();
    _notes = TextEditingController(text: override?.notes ?? widget.task.notes);
    _rrule = TextEditingController(text: widget.task.rrule ?? '');
    _reminderOffset = TextEditingController(
        text:
            reminder == null ? '30' : reminder.offsetMinutes.abs().toString());
    _status = override?.status ?? widget.task.status;
    _due = override != null
        ? override.due
        : widget.occurrence == null
            ? widget.task.due
            : _dueForOccurrence(widget.task, widget.occurrence!);
    _dateOnly = _due?.dateOnly ?? true;
    _reminderPolicy = override?.reminderPolicy ?? widget.task.reminderPolicy;
    _reminderEnabled =
        _reminderPolicy == ReminderPolicy.enabled || sourceReminders.isNotEmpty;
    _priority = (override?.priority ?? widget.task.priority).clamp(0, 3);
    _listId = override == null ? widget.task.listId : override.listId;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _rrule.dispose();
    _reminderOffset.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final l = AppLocalizations.of(context);
    final current = _due == null
        ? DateTime.now()
        : (_due!.dateOnly ? _due!.value : _due!.value.toLocal());
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: l.dueDate,
    );
    if (date == null || !mounted) return;

    if (_dateOnly) {
      setState(() => _due = DueDate(
            DateTime.utc(date.year, date.month, date.day),
            dateOnly: true,
          ));
      return;
    }

    final initialTime = TimeOfDay.fromDateTime(current);
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: l.dateAndTime,
    );
    if (time == null || !mounted) return;
    final local = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => _due = DueDate(local.toUtc(), dateOnly: false));
  }

  void _setDateOnly(bool value) {
    if (_due == null) {
      setState(() => _dateOnly = value);
      return;
    }
    final current = _due!.dateOnly ? _due!.value : _due!.value.toLocal();
    setState(() {
      _dateOnly = value;
      _due = value
          ? DueDate(DateTime.utc(current.year, current.month, current.day),
              dateOnly: true)
          : DueDate(DateTime(current.year, current.month, current.day,
                  current.hour, current.minute)
              .toUtc());
    });
  }

  List<Reminder> _reminders() {
    if (_reminderPolicy == ReminderPolicy.disabled) return const [];
    final original = widget.occurrence == null
        ? widget.task.reminders
        : widget.task.overrideFor(widget.occurrence!)?.reminders ??
            widget.task.reminders;
    if (_reminderPolicy == ReminderPolicy.inherit && original.isEmpty) {
      return const [];
    }
    final parsed = int.tryParse(_reminderOffset.text.trim()) ?? 0;
    final offset = parsed == 0 ? 0 : -parsed.abs();
    final id =
        original.isEmpty ? 'reminder-${widget.task.id}' : original.first.id;
    return [Reminder(id: id, offsetMinutes: offset)];
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).titleRequired)),
      );
      _titleFocus.requestFocus();
      return;
    }
    final rr = _rrule.text.trim();
    if (_reminderEnabled) {
      await AppNotifications.ensureNotificationPermission();
    }
    if (!mounted) return;
    if (widget.task.isRepeating && rr.isNotEmpty) {
      final occurrence = widget.occurrence ?? widget.task.due?.value;
      if (occurrence == null) return;
      final scope = await _chooseRecurrenceScope(
        defaultScope: widget.occurrence == null
            ? RecurrenceEditScope.wholeSeries
            : RecurrenceEditScope.occurrence,
      );
      if (scope == null || !mounted) return;
      if (scope != RecurrenceEditScope.occurrence && _due == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context).recurringDueRequired)),
        );
        return;
      }
      await widget.service.editRecurring(
        widget.task,
        scope: scope,
        occurrence: occurrence,
        title: title,
        notes: _notes.text.trim(),
        listId: _listId,
        due: _due,
        status: _status,
        rrule: rr,
        reminders: _reminders(),
        reminderPolicy: _reminderPolicy,
        priority: _priority,
      );
    } else {
      if (rr.isNotEmpty && _due == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context).recurringDueRequired)),
        );
        return;
      }
      await widget.service.edit(
        widget.task,
        title: title,
        notes: _notes.text.trim(),
        listId: _listId,
        due: _due,
        status: _status,
        rrule: rr.isEmpty ? null : rr,
        reminders: _reminders(),
        reminderPolicy: _reminderPolicy,
        priority: _priority,
      );
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<RecurrenceEditScope?> _chooseRecurrenceScope({
    required RecurrenceEditScope defaultScope,
  }) {
    var selected = defaultScope;
    return showDialog<RecurrenceEditScope>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).editRecurringTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioGroup<RecurrenceEditScope>(
                groupValue: selected,
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => selected = value);
                },
                child: Column(
                  children: RecurrenceEditScope.values.map((scope) {
                    final l = AppLocalizations.of(context);
                    final label = switch (scope) {
                      RecurrenceEditScope.occurrence => l.editThisOccurrence,
                      RecurrenceEditScope.thisAndFuture => l.editThisAndFuture,
                      RecurrenceEditScope.wholeSeries => l.editWholeSeries,
                    };
                    return RadioListTile<RecurrenceEditScope>(
                      value: scope,
                      title: Text(label),
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: Text(AppLocalizations.of(context).confirm),
            ),
          ],
        ),
      ),
    );
  }

  DueDate _dueForOccurrence(Task task, DateTime occurrence) {
    final dateOnly = task.due?.dateOnly ?? false;
    return dateOnly
        ? DueDate(
            DateTime.utc(occurrence.year, occurrence.month, occurrence.day),
            dateOnly: true,
          )
        : DueDate(occurrence);
  }

  String _statusLabel(TaskStatus s, AppLocalizations l) => switch (s) {
        TaskStatus.todo => l.todo,
        TaskStatus.doing => l.doing,
        TaskStatus.done => l.done,
      };

  String _priorityLabel(int priority, AppLocalizations l) => switch (priority) {
        1 => l.priorityLow,
        2 => l.priorityMedium,
        3 => l.priorityHigh,
        _ => l.priorityNone,
      };

  String _dueLabel(AppLocalizations l) {
    if (_due == null) return l.setDueDate;
    final value = _due!.dateOnly ? _due!.value : _due!.value.toLocal();
    final date = l.dateMonthDay(value.day, value.month);
    if (_due!.dateOnly) return date;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$date ${value.hour}:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.editTask)),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _save,
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(l.save),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(l.basicInformation),
                  const SizedBox(height: 10),
                  TextField(
                      focusNode: _titleFocus,
                      controller: _title,
                      decoration: InputDecoration(labelText: l.titleField)),
                  const SizedBox(height: 14),
                  TextField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: InputDecoration(labelText: l.notesField)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<TaskStatus>(
                    key: const ValueKey('task-status'),
                    initialValue: _status,
                    decoration: InputDecoration(labelText: l.statusField),
                    items: TaskStatus.values
                        .map((s) => DropdownMenuItem(
                            value: s, child: Text(_statusLabel(s, l))))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v ?? _status),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    key: const ValueKey('task-priority'),
                    initialValue: _priority,
                    decoration: InputDecoration(labelText: l.priority),
                    items: [0, 1, 2, 3]
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(_priorityLabel(value, l)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _priority = v ?? 0),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('task-list'),
                    initialValue: _listId ?? _inboxValue,
                    decoration: InputDecoration(labelText: l.lists),
                    items: [
                      DropdownMenuItem(
                          value: _inboxValue, child: Text(l.inbox)),
                      ...widget.lists.map((list) => DropdownMenuItem(
                            value: list.id,
                            child: Text(list.name),
                          )),
                    ],
                    onChanged: (v) =>
                        setState(() => _listId = v == _inboxValue ? null : v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(l.scheduling),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('task-due-picker'),
                          onPressed: _pickDue,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(_dueLabel(l),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      if (_due != null)
                        IconButton(
                          tooltip: l.clearDueDate,
                          onPressed: () => setState(() => _due = null),
                          icon: Icon(Icons.clear_rounded,
                              color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                  if (_due != null)
                    SwitchListTile(
                      key: const ValueKey('task-date-only'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.dateOnly),
                      subtitle: Text(_dateOnly ? l.dateOnly : l.dateAndTime,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 12)),
                      value: _dateOnly,
                      onChanged: _setDateOnly,
                    ),
                  const Divider(height: 20),
                  SwitchListTile(
                    key: const ValueKey('task-reminder-enabled'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.reminderEnabled),
                    subtitle: Text(
                        _reminderPolicy == ReminderPolicy.inherit
                            ? l.useDefaultReminder
                            : _reminderEnabled
                                ? l.reminder
                                : l.noReminder,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 12)),
                    value: _reminderEnabled,
                    onChanged: (value) => setState(() {
                      _reminderEnabled = value;
                      _reminderPolicy = value
                          ? ReminderPolicy.enabled
                          : ReminderPolicy.disabled;
                    }),
                  ),
                  if (_reminderEnabled)
                    TextField(
                      key: const ValueKey('task-reminder-offset'),
                      controller: _reminderOffset,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: l.reminderAdvanceMinutes),
                    ),
                  const SizedBox(height: 14),
                  TextField(
                      controller: _rrule,
                      decoration: InputDecoration(
                          labelText: l.repeatRule, hintText: l.repeatRuleHint)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
}
