import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/task_service.dart';
import '../theme/app_theme.dart';

class RecycleBinPage extends StatefulWidget {
  final TaskService service;
  const RecycleBinPage({super.key, required this.service});
  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage> {
  List<Task> _deleted = [];
  @override
  void initState() { super.initState(); _reload(); }
  Future<void> _reload() async {
    final all = await widget.service.query(includeDeleted: true);
    if (!mounted) return;
    setState(() => _deleted = all.where((t) => t.deleted).toList());
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: _deleted.isEmpty
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.delete_outline_rounded, size: 48, color: AppColors.muted),
              SizedBox(height: 14),
              Text('回收站是空的', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
              SizedBox(height: 6),
              Text('删除的任务会在这里，可恢复', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _deleted.length,
              itemBuilder: (c, i) {
                final t = _deleted[i];
                return Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: AppColors.muted),
                    title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(tooltip: '恢复', icon: const Icon(Icons.restore_rounded, color: AppColors.primary),
                          onPressed: () async { await widget.service.restore(t); await _reload(); }),
                      IconButton(tooltip: '彻底删除', icon: const Icon(Icons.delete_forever_rounded, color: AppColors.accent),
                          onPressed: () async { await widget.service.deletePermanent(t); await _reload(); }),
                    ]),
                  ),
                ));
              },
            ),
    );
  }
}
