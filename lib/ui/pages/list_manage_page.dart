import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/task_service.dart';
import '../../l10n/generated/app_localizations.dart';

class ListManagePage extends StatefulWidget {
  final TaskService service;
  const ListManagePage({super.key, required this.service});

  @override
  State<ListManagePage> createState() => _ListManagePageState();
}

class _ListManagePageState extends State<ListManagePage> {
  List<TaskList> _lists = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final lists = await widget.service.allLists();
    lists.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder == 0 ? a.name.compareTo(b.name) : byOrder;
    });
    if (!mounted) return;
    setState(() => _lists = lists);
  }

  Future<void> _editList([TaskList? list]) async {
    final l = AppLocalizations.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ListNameDialog(
        title: list == null ? l.newList : l.editList,
        initialName: list?.name ?? '',
        label: l.listName,
        cancelLabel: l.cancel,
        saveLabel: l.save,
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    if (list == null) {
      await widget.service.createList(name: result.trim());
    } else {
      await widget.service.editList(list, name: result.trim());
    }
    await _reload();
  }

  Future<void> _deleteList(TaskList list) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.deleteList),
        content: Text(l.deleteListConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.deleteList),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.service.deleteList(list);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.manageLists),
        actions: [
          IconButton(
            tooltip: l.newList,
            onPressed: () => _editList(),
            icon: const Icon(Icons.playlist_add_rounded),
          ),
        ],
      ),
      body: _lists.isEmpty
          ? SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.list_alt_rounded,
                        size: 48, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 14),
                    Text(l.noLists,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _editList(),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l.newList),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _lists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final list = _lists[index];
                return Card(
                  child: ListTile(
                    leading:
                        Icon(Icons.list_alt_rounded, color: scheme.primary),
                    title: Text(list.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l.editList,
                          onPressed: () => _editList(list),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: l.deleteList,
                          onPressed: () => _deleteList(list),
                          icon: Icon(Icons.delete_outline_rounded,
                              color: scheme.error),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ListNameDialog extends StatefulWidget {
  final String title;
  final String initialName;
  final String label;
  final String cancelLabel;
  final String saveLabel;

  const _ListNameDialog({
    required this.title,
    required this.initialName,
    required this.label,
    required this.cancelLabel,
    required this.saveLabel,
  });

  @override
  State<_ListNameDialog> createState() => _ListNameDialogState();
}

class _ListNameDialogState extends State<_ListNameDialog> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _name.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: TextField(
        controller: _name,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }
}
