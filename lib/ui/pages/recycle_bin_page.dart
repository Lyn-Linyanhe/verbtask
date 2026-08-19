import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: _deleted.isEmpty
          ? const Center(child: Text('回收站为空'))
          : ListView.builder(
              itemCount: _deleted.length,
              itemBuilder: (c, i) {
                final t = _deleted[i];
                return ListTile(
                  title: Text(t.title),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore),
                        tooltip: '恢复',
                        onPressed: () async { await widget.service.restore(t); await _reload(); },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever),
                        tooltip: '彻底删除',
                        onPressed: () async { await widget.service.deletePermanent(t); await _reload(); },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
