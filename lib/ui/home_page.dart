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

class HomePage extends StatefulWidget {
  final TaskRepository repository;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final SettingsController? settings;
  final ThemeMode themeMode;
  final VoidCallback? onQuickSync;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  const HomePage({
    super.key,
    required this.repository,
    required this.locale,
    required this.onLocaleChanged,
    this.settings,
    this.themeMode = ThemeMode.system,
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

  Future<void> _reschedule() => AppNotifications.rescheduleAll(
        widget.repository,
        defaultOffsetMinutes: widget.settings?.defaultReminderOffsetMinutes,
      );

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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认')),
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
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => RecycleBinPage(service: _tasks)));
    await _reload();
  }

  Future<void> _openEdit(Task t) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TaskEditPage(task: t, service: _tasks)),
    );
    if (changed == true) {
      await _reschedule();
      await _reload();
    }
  }

  Future<void> _openSettings() async {
    final s = widget.settings;
    if (s == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SettingsPage(
              controller: s,
              onLocaleChanged: widget.onLocaleChanged,
              onQuickSync: widget.onQuickSync,
              themeMode: widget.themeMode,
              onThemeModeChanged: widget.onThemeModeChanged),
        ));
    await _reschedule();
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
              child: _PillTabs(
                  current: _tab,
                  onChanged: (v) {
                    setState(() => _tab = v!);
                    _reload();
                  },
                  l: l),
            ),
            Expanded(
              child: _items.isEmpty
                  ? _EmptyState(tab: _tab, l: l)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _items.length,
                      itemBuilder: (c, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: _TaskCard(
                          task: _items[i],
                          onTap: () => _openEdit(_items[i]),
                          onToggle: (v) async {
                            await _tasks.setDone(_items[i], v);
                            await _reschedule();
                            await _reload();
                          },
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
  const _AppHeader(
      {required this.title,
      this.onQuickSync,
      required this.onRecycle,
      required this.onMenu,
      required this.hasSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 6, 8),
      child: Row(
        children: [
          Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700, letterSpacing: -0.4))),
          IconButton(
              tooltip: '快速同步',
              onPressed: onQuickSync,
              icon: const Icon(Icons.sync_rounded)),
          IconButton(
              tooltip: '回收站',
              onPressed: onRecycle,
              icon: const Icon(Icons.delete_outline_rounded)),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: onMenu,
            itemBuilder: (c) => [
              if (hasSettings)
                PopupMenuItem(
                    value: 'settings',
                    child: Row(children: [
                      Icon(Icons.settings_outlined,
                          size: 20,
                          color: Theme.of(c).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      const Text('设置')
                    ])),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'zh',
                  child: Row(children: [SizedBox(width: 2), Text('中文')])),
              const PopupMenuItem(
                  value: 'en',
                  child: Row(children: [SizedBox(width: 2), Text('English')])),
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
  const _PillTabs(
      {required this.current, required this.onChanged, required this.l});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (btn: 'inbox', label: l.inbox, icon: Icons.inbox_rounded),
      (btn: 'list', label: l.lists, icon: Icons.list_alt_rounded),
      (btn: 'done', label: l.done, icon: Icons.check_rounded),
    ];
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
      child: Row(
        children: tabs.map((t) {
          final sel = current == t.btn;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(t.btn),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(t.icon,
                            size: 16,
                            color:
                                sel ? scheme.primary : scheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(t.label,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w500,
                                color: sel
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 2,
                    width: sel ? 42 : 0,
                    color: scheme.primary,
                  ),
                ],
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
    final scheme = Theme.of(context).colorScheme;
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
            width: 84,
            height: 84,
            decoration: BoxDecoration(
                color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(icon, size: 38, color: scheme.primary),
          ),
          const SizedBox(height: 18),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(sub,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  const _TaskCard(
      {required this.task, required this.onTap, required this.onToggle});

  Color _statusColor(ColorScheme scheme) => switch (task.status) {
        TaskStatus.done => scheme.tertiary,
        TaskStatus.doing => scheme.primary,
        TaskStatus.todo => scheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
          child: Row(
            children: [
              Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _statusColor(scheme), shape: BoxShape.circle)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => onToggle(!done),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? scheme.tertiary : Colors.transparent,
                    border: Border.all(
                        color: done ? scheme.tertiary : scheme.outline,
                        width: 1.6),
                  ),
                  child: done
                      ? Icon(Icons.check, size: 14, color: scheme.onTertiary)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: done
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                            decoration:
                                done ? TextDecoration.lineThrough : null)),
                    if (task.due != null) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(Icons.schedule_rounded,
                            size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(_fmt(task.due!),
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant)),
                      ]),
                    ],
                  ],
                ),
              ),
              if (task.isRepeating)
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.repeat_rounded,
                        size: 16, color: scheme.primary)),
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
    final urgent =
        overdue || due.value.toLocal().difference(DateTime.now()).inDays == 0;
    final scheme = Theme.of(context).colorScheme;
    final color = overdue
        ? scheme.error
        : (urgent ? scheme.primary : scheme.onSurfaceVariant);
    return Text(overdue ? '已逾期' : (urgent ? '今天' : '有期限'),
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color));
  }
}
