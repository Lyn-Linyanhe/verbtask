import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/models/models.dart';
import '../core/services/task_service.dart';
import '../core/nlp/nlp_service.dart';
import '../core/storage/repository.dart';
import '../core/settings/settings_controller.dart';
import '../core/notifications/app_notifications.dart';
import 'pages/board_page.dart';
import 'pages/list_manage_page.dart';
import 'pages/task_edit_page.dart';
import 'pages/recycle_bin_page.dart';
import 'pages/settings_page.dart';

enum ViewFilter { inbox, today, planned, list, done, board }

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
  final TextEditingController _input = TextEditingController();
  final TextEditingController _search = TextEditingController();
  List<Task> _items = const [];
  List<TaskList> _lists = const [];
  ViewFilter _view = ViewFilter.inbox;
  String? _selectedListId;
  TaskStatus? _statusFilter;
  BySort _sort = BySort.dueAsc;
  int _reloadToken = 0;

  @override
  void initState() {
    super.initState();
    _tasks = TaskService(widget.repository);
    _reload();
  }

  @override
  void dispose() {
    _input.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reschedule() => AppNotifications.rescheduleAll(
        widget.repository,
        defaultOffsetMinutes: widget.settings?.defaultReminderOffsetMinutes,
      );

  Future<void> _reload() async {
    final token = ++_reloadToken;
    final view = _view;
    final lists = await _tasks.allLists();
    lists.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder == 0 ? a.name.compareTo(b.name) : byOrder;
    });

    var selectedListId = _selectedListId;
    if (view == ViewFilter.list && selectedListId == null && lists.isNotEmpty) {
      selectedListId = lists.first.id;
    }
    if (selectedListId != null &&
        !lists.any((list) => list.id == selectedListId)) {
      selectedListId = lists.isEmpty ? null : lists.first.id;
    }

    String? listId;
    TaskStatus? status;
    DateTime? dueFrom;
    DateTime? dueTo;
    var includeDone = false;
    switch (view) {
      case ViewFilter.inbox:
        listId = null;
      case ViewFilter.today:
        dueTo =
            _startOfDay(DateTime.now().add(const Duration(days: 1))).toUtc();
      case ViewFilter.planned:
        break;
      case ViewFilter.list:
        listId = selectedListId;
      case ViewFilter.done:
        status = TaskStatus.done;
        includeDone = true;
      case ViewFilter.board:
        includeDone = true;
    }

    if (view != ViewFilter.done && view != ViewFilter.board) {
      status = _statusFilter;
    }

    var items = await _tasks.query(
      search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      listId: listId,
      status: status,
      includeDone: includeDone,
      dueFrom: dueFrom,
      dueTo: dueTo,
      by: _sort,
    );
    if (view == ViewFilter.planned) {
      items = items.where((task) => task.due != null).toList();
    } else if (view == ViewFilter.list && selectedListId == null) {
      items = items.where((task) => !task.isInInbox).toList();
    }

    if (!mounted || token != _reloadToken) return;
    setState(() {
      _items = items;
      _lists = lists;
      _selectedListId = selectedListId;
    });
  }

  DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Future<void> _quickAdd(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    final r = _nlp.parseLocal(value);
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).addTask),
        content: Text(
          '${l.parseTitle(r.title ?? l.unrecognized)}\n'
          '${l.parseDue(r.due?.value.toLocal() ?? l.none)}\n'
          '${l.parseRepeat(r.rrule ?? l.none)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel,
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _tasks.create(
        title: r.title ?? value,
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecycleBinPage(service: _tasks)),
    );
    await _reload();
  }

  Future<void> _openEdit(Task task) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => TaskEditPage(task: task, service: _tasks)),
    );
    if (changed == true) {
      await _reschedule();
      await _reload();
    }
  }

  Future<void> _openLists() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ListManagePage(service: _tasks)),
    );
    await _reload();
  }

  Future<void> _openBoard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              BoardPage(service: _tasks, onTaskChanged: _reschedule)),
    );
    await _reload();
  }

  Future<void> _openSettings() async {
    final settings = widget.settings;
    if (settings == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          controller: settings,
          onLocaleChanged: widget.onLocaleChanged,
          onQuickSync: widget.onQuickSync,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
      ),
    );
    await _reschedule();
  }

  void _onMenu(String value) {
    switch (value) {
      case 'settings':
        _openSettings();
      case 'lists':
        _openLists();
      case 'zh':
        widget.onLocaleChanged(const Locale('zh'));
      case 'en':
        widget.onLocaleChanged(const Locale('en'));
    }
  }

  void _changeView(ViewFilter view) {
    if (view == ViewFilter.board) {
      _openBoard();
      return;
    }
    setState(() {
      _view = view;
      if (view == ViewFilter.list &&
          _selectedListId == null &&
          _lists.isNotEmpty) {
        _selectedListId = _lists.first.id;
      }
    });
    _reload();
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
              l: l,
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
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: TextField(
                controller: _search,
                onChanged: (_) {
                  setState(() {});
                  _reload();
                },
                decoration: InputDecoration(
                  hintText: l.searchTasks,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l.clearSearch,
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                            _reload();
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _ViewTabs(
                current: _view,
                onChanged: _changeView,
                l: l,
              ),
            ),
            if (_view == ViewFilter.list)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedListId,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l.selectList),
                        items: _lists
                            .map((list) => DropdownMenuItem<String>(
                                  value: list.id,
                                  child: Text(list.name,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedListId = value);
                          _reload();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: l.manageLists,
                      onPressed: _openLists,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: _QueryControls(
                sort: _sort,
                status: _statusFilter,
                l: l,
                onSortChanged: (value) {
                  setState(() => _sort = value);
                  _reload();
                },
                onStatusChanged: (value) {
                  setState(() => _statusFilter = value);
                  _reload();
                },
              ),
            ),
            Expanded(
              child: _items.isEmpty
                  ? _EmptyState(view: _view, l: l)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final task = _items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 1),
                          child: _TaskCard(
                            task: task,
                            onTap: () => _openEdit(task),
                            onToggle: (done) async {
                              await _tasks.setDone(task, done);
                              await _reschedule();
                              await _reload();
                            },
                          ),
                        );
                      },
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
  final AppLocalizations l;
  final VoidCallback? onQuickSync;
  final VoidCallback onRecycle;
  final ValueChanged<String> onMenu;
  final bool hasSettings;

  const _AppHeader({
    required this.title,
    required this.l,
    this.onQuickSync,
    required this.onRecycle,
    required this.onMenu,
    required this.hasSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 6, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
              tooltip: l.quickSync,
              onPressed: onQuickSync,
              icon: const Icon(Icons.sync_rounded)),
          IconButton(
              tooltip: l.recycleBin,
              onPressed: onRecycle,
              icon: const Icon(Icons.delete_outline_rounded)),
          PopupMenuButton<String>(
            tooltip: l.more,
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: onMenu,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'lists',
                child: Row(children: [
                  Icon(Icons.list_alt_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text(l.manageLists),
                ]),
              ),
              if (hasSettings)
                PopupMenuItem(
                  value: 'settings',
                  child: Row(children: [
                    Icon(Icons.settings_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Text(l.settings),
                  ]),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'zh', child: Text(l.languageChinese)),
              PopupMenuItem(value: 'en', child: Text(l.languageEnglish)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewTabs extends StatelessWidget {
  final ViewFilter current;
  final ValueChanged<ViewFilter> onChanged;
  final AppLocalizations l;

  const _ViewTabs({
    required this.current,
    required this.onChanged,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (view: ViewFilter.inbox, label: l.inbox, icon: Icons.inbox_rounded),
      (view: ViewFilter.list, label: l.lists, icon: Icons.list_alt_rounded),
      (view: ViewFilter.today, label: l.today, icon: Icons.today_rounded),
      (view: ViewFilter.planned, label: l.planned, icon: Icons.event_rounded),
      (view: ViewFilter.done, label: l.done, icon: Icons.check_rounded),
      (view: ViewFilter.board, label: l.board, icon: Icons.view_kanban_rounded),
    ];
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 46,
      child: ListView.separated(
        key: const ValueKey('view-tabs'),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final selected = current == tab.view;
          return ChoiceChip(
            key: ValueKey('view-${tab.view.name}'),
            selected: selected,
            label: Text(tab.label),
            avatar: Icon(tab.icon, size: 16),
            onSelected: (_) => onChanged(tab.view),
            labelStyle: TextStyle(
                color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
          );
        },
      ),
    );
  }
}

class _QueryControls extends StatelessWidget {
  final BySort sort;
  final TaskStatus? status;
  final AppLocalizations l;
  final ValueChanged<BySort> onSortChanged;
  final ValueChanged<TaskStatus?> onStatusChanged;

  const _QueryControls({
    required this.sort,
    required this.status,
    required this.l,
    required this.onSortChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<BySort>(
            initialValue: sort,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.filter),
            items: [
              DropdownMenuItem(
                  value: BySort.dueAsc,
                  child: Text(l.sortByDue, overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(
                  value: BySort.createdDesc,
                  child:
                      Text(l.sortByCreated, overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(
                  value: BySort.titleAsc,
                  child: Text(l.sortByTitle, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) {
              if (value != null) onSortChanged(value);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: status?.name ?? 'all',
            isExpanded: true,
            decoration: InputDecoration(labelText: l.statusField),
            items: [
              DropdownMenuItem(value: 'all', child: Text(l.allStatuses)),
              DropdownMenuItem(value: 'todo', child: Text(l.todo)),
              DropdownMenuItem(value: 'doing', child: Text(l.doing)),
              DropdownMenuItem(value: 'done', child: Text(l.done)),
            ],
            onChanged: (value) => onStatusChanged(switch (value) {
              'todo' => TaskStatus.todo,
              'doing' => TaskStatus.doing,
              'done' => TaskStatus.done,
              _ => null,
            }),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ViewFilter view;
  final AppLocalizations l;
  const _EmptyState({required this.view, required this.l});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, title, sub) = switch (view) {
      ViewFilter.inbox => (
          Icons.inbox_rounded,
          l.emptyInboxTitle,
          l.emptyInboxSubtitle
        ),
      ViewFilter.today => (
          Icons.today_rounded,
          l.emptyTodayTitle,
          l.emptyTodaySubtitle
        ),
      ViewFilter.planned => (
          Icons.event_rounded,
          l.emptyPlannedTitle,
          l.emptyPlannedSubtitle
        ),
      ViewFilter.done => (
          Icons.task_alt_rounded,
          l.emptyDoneTitle,
          l.emptyDoneSubtitle
        ),
      ViewFilter.board => (
          Icons.view_kanban_rounded,
          l.emptyBoardTitle,
          l.emptyBoardSubtitle
        ),
      ViewFilter.list => (
          Icons.list_alt_rounded,
          l.emptyListTitle,
          l.emptyListSubtitle
        ),
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
                        Text(_fmt(task.due!, AppLocalizations.of(context)),
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

  String _fmt(DueDate due, AppLocalizations l) {
    final d = due.value.toLocal();
    final date = l.dateMonthDay(d.day, d.month);
    if (due.dateOnly) return date;
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$date $h:$min';
  }
}

class _DueChip extends StatelessWidget {
  final DueDate due;
  const _DueChip({required this.due});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final local = due.value.toLocal();
    final overdue = local.isBefore(DateTime.now());
    final urgent = overdue || local.difference(DateTime.now()).inDays == 0;
    final scheme = Theme.of(context).colorScheme;
    final color = overdue
        ? scheme.error
        : (urgent ? scheme.primary : scheme.onSurfaceVariant);
    return Text(overdue ? l.overdue : (urgent ? l.today : l.hasDueDate),
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color));
  }
}
