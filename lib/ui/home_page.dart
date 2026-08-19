import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/models/models.dart';
import '../core/services/task_service.dart';
import '../core/nlp/nlp_service.dart';
import '../core/storage/repository.dart';
import '../core/settings/settings_controller.dart';
import '../core/notifications/app_notifications.dart';
import 'pages/task_edit_page.dart';
import 'pages/recycle_bin_page.dart';
import 'pages/settings_page.dart';
import 'theme/app_theme.dart';

class HomePage extends StatefulWidget {
  final TaskRepository repository;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final SettingsController? settings;
  final VoidCallback? onQuickSync;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  const HomePage({
    super.key,
    required this.repository,
    required this.locale,
    required this.onLocaleChanged,
    this.settings,
    this.onQuickSync,
    this.onThemeModeChanged,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(
          '标题: ${r.title ?? '（未识别）'}\n'
          '截止: ${r.due?.value ?? '（无）'}\n'
          '重复: ${r.rrule ?? '（无）'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消', style: TextStyle(color: AppColors.muted))),
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
    if (changed == true) { await _reschedule(); await _reload(); }
  }

  Future<void> _openSettings() async {
    final s = widget.settings;
    if (s == null) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => SettingsPage(controller: s, onLocaleChanged: widget.onLocaleChanged, onQuickSync: widget.onQuickSync, onThemeModeChanged: widget.onThemeModeChanged),
    ));
  }

  void _onMenu(String value) {
    switch (value) {
      case 'settings':
        _openSettings();
      case 'zh':
        widget.onLocaleChanged(const Locale('zh'));
      case 'en':
        widget.onLocaleChanged(const Locale('en'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppHeader(
              title: l.appTitle,
              onQuickSync: widget.onQuickSync,
              onRecycle: _openBin,
              onMenu: _onMenu,
              hasSettings: widget.settings != null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _input,
                onSubmitted: _quickAdd,
                decoration: InputDecoration(
                  hintText: l.addTask,
                  prefixIcon: const Icon(Icons.add_rounded),
                  suffixIcon: _input.text.isEmpty ? null : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _PillTabs(current: _tab, onChanged: (v) { setState(() => _tab = v!); _reload(); }, l: l),
            ),
            Expanded(
              child: _items.isEmpty
                  ? _EmptyState(tab: _tab, l: l)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _items.length,
                      itemBuilder: (c, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TaskCard(
                          task: _items[i],
                          onTap: () => _openEdit(_items[i]),
                          onToggle: (v) async { await _tasks.setDone(_items[i], v); await _reschedule(); await _reload(); },
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

class _AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onQuickSync;
  final VoidCallback onRecycle;
  final ValueChanged<String> onMenu;
  final bool hasSettings;
  const _AppHeader({required this.title, this.onQuickSync, required this.onRecycle, required this.onMenu, required this.hasSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 6, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.4))),
          IconButton(tooltip: '快速同步', onPressed: onQuickSync, icon: const Icon(Icons.sync_rounded)),
          IconButton(tooltip: '回收站', onPressed: onRecycle, icon: const Icon(Icons.delete_outline_rounded)),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: onMenu,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (c) => [
              if (hasSettings) const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings_outlined, size: 20, color: AppColors.muted), SizedBox(width: 10), Text('设置')])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'zh', child: Row(children: [SizedBox(width: 2), Text('中文')])),
              const PopupMenuItem(value: 'en', child: Row(children: [SizedBox(width: 2), Text('English')])),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillTabs extends StatelessWidget {
  final String? current;
  final ValueChanged<String?> onChanged;
  final AppLocalizations l;
  const _PillTabs({required this.current, required this.onChanged, required this.l});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (btn: 'inbox', label: l.inbox, icon: Icons.inbox_rounded),
      (btn: 'list', label: l.lists, icon: Icons.list_alt_rounded),
      (btn: 'done', label: l.done, icon: Icons.check_rounded),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: tabs.map((t) {
          final sel = current == t.btn;
          return Expanded(
            child: Material(
              color: sel ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(t.btn),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.icon, size: 16, color: sel ? Colors.white : AppColors.muted),
                      const SizedBox(width: 6),
                      Text(t.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.text)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String tab;
  final AppLocalizations l;
  const _EmptyState({required this.tab, required this.l});

  @override
  Widget build(BuildContext context) {
    final (icon, title, sub) = switch (tab) {
      'inbox' => (Icons.inbox_rounded, '收件箱是空的', '把要做的事记下来，随手完成'),
      'done' => (Icons.task_alt_rounded, '还没有已完成的任务', '勾选任务即可在这里看到'),
      _ => (Icons.list_alt_rounded, '还没有清单任务', '把任务归入清单，分门别类'),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84, height: 84,
            decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Icon(icon, size: 38, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 6),
          Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  const _TaskCard({required this.task, required this.onTap, required this.onToggle});

  Color get _statusColor => switch (task.status) {
        TaskStatus.done => AppColors.done,
        TaskStatus.doing => AppColors.primary,
        TaskStatus.todo => AppColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(width: 4, height: 40, decoration: BoxDecoration(color: _statusColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 12),
              // 自定义完成圈
              GestureDetector(
                onTap: () => onToggle(!done),
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? AppColors.done : Colors.transparent,
                    border: Border.all(color: done ? AppColors.done : AppColors.line, width: 1.6),
                  ),
                  child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                            color: done ? AppColors.muted : AppColors.text,
                            decoration: done ? TextDecoration.lineThrough : null)),
                    if (task.due != null) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(Icons.schedule_rounded, size: 13, color: AppColors.muted),
                        const SizedBox(width: 3),
                        Text(_fmt(task.due!), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ]),
                    ],
                  ],
                ),
              ),
              if (task.isRepeating) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.repeat_rounded, size: 16, color: AppColors.primary)),
              if (task.due != null) _DueChip(due: task.due!),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DueDate due) {
    final d = due.value.toLocal();
    final m = '${d.month}月${d.day}日';
    if (due.dateOnly) return m;
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$m $h:$min';
  }
}

class _DueChip extends StatelessWidget {
  final DueDate due;
  const _DueChip({required this.due});
  @override
  Widget build(BuildContext context) {
    final overdue = due.value.toLocal().isBefore(DateTime.now());
    final urgent = overdue || due.value.toLocal().difference(DateTime.now()).inDays == 0;
    final color = overdue ? AppColors.accent : (urgent ? AppColors.primary : AppColors.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(overdue ? '已逾期' : (urgent ? '今天' : '有期限'),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}




