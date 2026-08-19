import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/models/models.dart';
import '../core/services/task_service.dart';
import '../core/nlp/nlp_service.dart';
import '../core/notifications/app_notifications.dart';
import '../core/storage/repository.dart';
import '../core/settings/settings_controller.dart';
import 'pages/task_edit_page.dart';
import 'pages/recycle_bin_page.dart';
import 'pages/settings_page.dart';

class HomePage extends StatefulWidget {
  final TaskRepository repository;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final SettingsController? settings;
  final VoidCallback? onQuickSync;
  const HomePage({
    super.key,
    required this.repository,
    required this.locale,
    required this.onLocaleChanged,
    this.settings,
    this.onQuickSync,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late TaskService _tasks;
  final NlpService _nlp = NlpService();
  List<Task> _items = [];
  String _tab = 'inbox';
  final TextEditingController _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tasks = TaskService(widget.repository);
    _reload();
  }

  Future<void> _reschedule() => AppNotifications.rescheduleAll(widget.repository);

  Future<void> _reload() async {
    final all = await _tasks.query(includeDeleted: false);
    if (!mounted) return;
    setState(() {
      _items = switch (_tab) {
        'inbox' => all.where((t) => t.isInInbox).toList(),
        'done' => all.where((t) => t.status == TaskStatus.done).toList(),
        _ => all.where((t) => !t.isInInbox).toList(),
      };
    });
  }

  Future<void> _quickAdd(String text) async {
    final r = _nlp.parseLocal(text);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).addTask),
        content: Text(
          '标题: ${r.title ?? '（未识别）'}\n'
          '截止: ${r.due?.value ?? '（无）'}\n'
          '重复: ${r.rrule ?? '（无）'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed == true) {
      await _tasks.create(
        title: r.title ?? text,
        due: r.due,
        rrule: r.rrule,
        priority: r.priority ?? 0,
      );
      await _reschedule();
      _input.clear();
      await _reload();
    }
  }

  Future<void> _openBin() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RecycleBinPage(service: _tasks)));
    await _reload();
  }

  Future<void> _openEdit(Task t) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TaskEditPage(task: t, service: _tasks)),
    );
    if (changed == true) await _reload();
  }

  Future<void> _openSettings() async {
    final s = widget.settings;
    if (s == null) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => SettingsPage(
        controller: s,
        onLocaleChanged: widget.onLocaleChanged,
        onQuickSync: widget.onQuickSync,
      ),
    ));
  }

  void _chooseLanguage() {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppLocalizations.of(ctx).language),
        children: [
          SimpleDialogOption(
            onPressed: () { widget.onLocaleChanged(const Locale('zh')); Navigator.pop(ctx); },
            child: const Text('中文'),
          ),
          SimpleDialogOption(
            onPressed: () { widget.onLocaleChanged(const Locale('en')); Navigator.pop(ctx); },
            child: const Text('English'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          IconButton(icon: const Icon(Icons.delete), tooltip: '回收站', onPressed: _openBin),
          if (widget.settings != null)
            IconButton(icon: const Icon(Icons.settings), tooltip: '设置', onPressed: _openSettings),
          IconButton(icon: const Icon(Icons.translate), tooltip: l.language, onPressed: _chooseLanguage),
          IconButton(icon: const Icon(Icons.update), tooltip: l.quickSync, onPressed: widget.onQuickSync ?? () {}),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _input,
              onSubmitted: _quickAdd,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: l.addTask,
                prefixIcon: const Icon(Icons.add_task_outlined),
              ),
            ),
          ),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'inbox', label: Text(l.inbox)),
              ButtonSegment(value: 'list', label: Text(l.lists)),
              ButtonSegment(value: 'done', label: Text(l.done)),
            ],
            selected: {_tab},
            onSelectionChanged: (s) { setState(() => _tab = s.first); _reload(); },
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('暂无任务'))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (c, i) {
                      final t = _items[i];
                      return ListTile(
                        onTap: () => _openEdit(t),
                        leading: Checkbox(
                          value: t.status == TaskStatus.done,
                          onChanged: (v) async { await _tasks.setDone(t, v ?? false); await _reschedule(); await _reload(); },
                        ),
                        title: Text(t.title),
                        subtitle: t.due != null ? Text('截止: ${t.due!.value.toLocal()}') : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

