import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/models/models.dart';
import '../../core/services/task_service.dart';

class RecycleBinPage extends StatefulWidget {
  final TaskService service;
  const RecycleBinPage({super.key, required this.service});
  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage> {
  List<Task> _deleted = [];
  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final all = await widget.service.query(includeDeleted: true);
    if (!mounted) return;
    setState(() => _deleted = all.where((t) => t.deleted).toList());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.recycleBin)),
      body: _deleted.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.delete_outline_rounded,
                  size: 48, color: scheme.onSurfaceVariant),
              SizedBox(height: 14),
              Text(l.emptyRecycleBinTitle,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text(l.emptyRecycleBinSubtitle,
                  style:
                      TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _deleted.length,
              itemBuilder: (c, i) {
                final t = _deleted[i];
                return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: Icon(Icons.delete_outline_rounded,
                            color: scheme.onSurfaceVariant),
                        title: Text(t.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              tooltip: l.restore,
                              icon: Icon(Icons.restore_rounded,
                                  color: scheme.primary),
                              onPressed: () async {
                                await widget.service.restore(t);
                                await _reload();
                              }),
                          IconButton(
                              tooltip: l.deletePermanently,
                              icon: Icon(Icons.delete_forever_rounded,
                                  color: scheme.error),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(l.deletePermanentlyConfirmTitle),
                                    content: Text(l.deletePermanentlyConfirmBody),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: Text(l.cancel)),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                            backgroundColor:
                                                Theme.of(ctx).colorScheme.error),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: Text(l.deletePermanently),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await widget.service.deletePermanent(t);
                                  await _reload();
                                }
                              }),
                        ]),
                      ),
                    ));
              },
            ),
    );
  }
}
