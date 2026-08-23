import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/models/models.dart';
import '../core/services/task_service.dart';
import '../core/nlp/nlp_service.dart';
import '../core/nlp/llm_client.dart';
import '../core/storage/repository.dart';
import '../core/settings/settings_controller.dart';
import '../core/notifications/app_notifications.dart';
import 'pages/board_page.dart';
import 'pages/list_manage_page.dart';
import 'pages/task_edit_page.dart';
import 'pages/recycle_bin_page.dart';
import 'pages/settings_page.dart';
import 'pages/quick_note_page.dart';
import '../app/window_control.dart';

enum ViewFilter { inbox, today, planned, list, done, board }

class HomePage extends StatefulWidget {
  final TaskRepository repository;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final SettingsController? settings;
  final ThemeMode themeMode;
  final Future<void> Function()? onQuickSync;
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
  final NlpService _nlp = NlpService(llm: LlmClient());
  final TextEditingController _input = TextEditingController();
  final TextEditingController _search = TextEditingController();
  List<Task> _items = const [];
  List<TaskList> _lists = const [];
  ViewFilter _view = ViewFilter.inbox;
  String? _selectedListId;
  TaskStatus? _statusFilter;
  BySort _sort = BySort.dueAsc;
  int _reloadToken = 0;
  bool _quickAdding = false;

  @override
  void initState() {
    super.initState();
    _tasks = TaskService(widget.repository, onChanged: _reschedule);
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
        language: widget.settings?.language ?? widget.locale.languageCode,
      );

  Future<void> _reload() async {
    final token = ++_reloadToken;
    final view = _view;
    final lists = await _tasks.allLists();
    if (!mounted) return;
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
        dueFrom = _startOfDay(DateTime.now()).toUtc();
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
      inboxOnly: view == ViewFilter.inbox,
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

  Future<bool> _quickAdd(String text) async {
    if (_quickAdding) return false;
    final value = text.trim();
    if (value.isEmpty) return false;
    setState(() => _quickAdding = true);
    final l = AppLocalizations.of(context);
    try {
      var config = _llmConfig();
      if (config != null) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(ctx).llmDataNoticeTitle),
            content: Text(AppLocalizations.of(ctx).llmDataNoticeBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(ctx).cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.of(ctx).confirm),
              ),
            ],
          ),
        );
        if (proceed != true) config = null;
      }

      final r = await _nlp.parse(value, config: config);
      if (!mounted) return false;
      if (r.title == null || r.title!.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.unrecognizedInput)),
        );
        return false;
      }
      final matchedList = r.listName == null
          ? null
          : _lists.cast<TaskList?>().firstWhere(
                (list) =>
                    list!.name.trim().toLowerCase() ==
                    r.listName!.trim().toLowerCase(),
                orElse: () => null,
              );
      final parsedTitle = matchedList == null && r.listName != null
          ? '${r.title ?? value} #${r.listName}'
          : (r.title ?? value);
      // 提醒：明确关闭优先；未提及时才继承全局默认提前量。
      // An advance reminder without a due date cannot be scheduled. Keep the
      // note, but never persist an enabled reminder that cannot fire.
      final explicitReminderMin = r.reminderNeedsDue ? null : r.reminderMinutes;
      int? reminderMin = explicitReminderMin;
      if (!r.reminderDisabled &&
          reminderMin == null &&
          r.due != null &&
          (widget.settings?.notifyDefaultReminderEnabled ?? false)) {
        reminderMin = (widget.settings?.notifyDefaultOffsetMin ?? -15).abs();
      }
      final reminderLabel = r.reminderDisabled
          ? l.noReminder
          : reminderMin == null
              ? l.noReminder
              : (reminderMin == 0
                  ? l.remindAtDue
                  : l.remindBeforeMinutes(reminderMin));
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(ctx).addTask),
          content: Text(
            '${l.parseTitle(parsedTitle.isEmpty ? l.unrecognized : parsedTitle)}\n'
            '${l.parseDue(r.due?.value.toLocal() ?? l.none)}\n'
            '${l.parseRepeat(r.rrule ?? l.none)}\n'
            '${l.parseList(matchedList?.name ?? l.inbox)}\n'
            '${l.parseReminder(r.reminderNeedsDue ? l.reminderNeedsDue : reminderLabel)}\n'
            '${l.parsePriority(_priorityName(r.priority, l))}\n'
            '${l.parseSource(r.source == 'llm' ? l.parseLlm : l.parseLocal)}'
            '${r.fallbackFromLlm ? '\n${l.llmFallbackNotice}' : ''}',
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
        final reminders = r.reminderDisabled || explicitReminderMin == null
            ? const <Reminder>[]
            : [
                Reminder(
                  id: 'rem-${DateTime.now().microsecondsSinceEpoch}',
                  offsetMinutes:
                      explicitReminderMin == 0 ? 0 : -explicitReminderMin,
                )
              ];
        if (reminders.isNotEmpty) {
          await AppNotifications.ensureNotificationPermission();
        }
        await _tasks.create(
          title: parsedTitle,
          listId: matchedList?.id,
          due: r.due,
          rrule: r.rrule,
          priority: r.priority ?? 0,
          reminders: reminders,
          reminderPolicy: r.reminderDisabled
              ? ReminderPolicy.disabled
              : explicitReminderMin == null
                  ? ReminderPolicy.inherit
                  : ReminderPolicy.enabled,
        );
        await _reschedule();
        _input.clear();
        await _reload();
        return true;
      }
      return false;
    } finally {
      if (mounted) setState(() => _quickAdding = false);
    }
  }

  LlmConfig? _llmConfig() {
    final s = widget.settings;
    if (s == null || s.llmEnabled != 1) return null;
    final base = s.llmBaseUrl.trim();
    final key = s.llmKey.trim();
    if (base.isEmpty || key.isEmpty) return null;
    return LlmConfig(baseUrl: base, apiKey: key, model: s.llmModel.trim());
  }

  String _priorityName(int? priority, AppLocalizations l) => switch (priority) {
        1 => l.priorityLow,
        2 => l.priorityMedium,
        3 => l.priorityHigh,
        _ => l.priorityNone,
      };

  Future<void> _openBin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecycleBinPage(service: _tasks)),
    );
    await _reload();
  }

  Future<void> _openEdit(Task task) async {
    final lists = await _tasks.allLists();
    if (!mounted) return;
    lists.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder == 0 ? a.name.compareTo(b.name) : byOrder;
    });
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              TaskEditPage(task: task, service: _tasks, lists: lists)),
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
          onReminderSettingsChanged: _reschedule,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
      ),
    );
    await _reschedule();
  }

  /// 打开悬浮速记小窗：窗口缩成小窗并置顶，回车连记，返回恢复窗口。
  Future<void> _openQuickNote() async {
    await WindowControl.enterMini();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickNotePage(
          onAdd: _quickAdd,
          restoreAlwaysOnTop: widget.settings?.alwaysOnTop ?? false,
        ),
      ),
    );
    if (mounted) {
      await WindowControl.exitMini(
          restoreAlwaysOnTop: widget.settings?.alwaysOnTop ?? false);
    }
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
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _AppHeader(
                title: l.appTitle,
                l: l,
                onQuickSync: widget.onQuickSync,
                onQuickNote: _openQuickNote,
                onRecycle: _openBin,
                onMenu: _onMenu,
                hasSettings: widget.settings != null,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
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
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: TextField(
                  controller: _search,
                  onChanged: (_) {
                    setState(() {});
                    _reload();
                  },
                  decoration: InputDecoration(
                    hintText: l.searchTasks,
                    isDense: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerLow,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
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
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: _ViewTabs(
                  current: _view,
                  onChanged: _changeView,
                  l: l,
                ),
              ),
            ),
            if (_view == ViewFilter.list)
              SliverToBoxAdapter(
                child: Padding(
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
              ),
            SliverToBoxAdapter(
              child: Padding(
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
            ),
            if (_items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _search.text.trim().isNotEmpty
                    ? _SearchEmpty(
                        l: l,
                        onClear: () {
                          _search.clear();
                          setState(() {});
                          _reload();
                        },
                      )
                    : _EmptyState(view: _view, l: l),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
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
                    childCount: _items.length,
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
  final AppLocalizations l;
  final Future<void> Function()? onQuickSync;
  final VoidCallback onRecycle;
  final VoidCallback? onQuickNote;
  final ValueChanged<String> onMenu;
  final bool hasSettings;

  const _AppHeader({
    required this.title,
    required this.l,
    this.onQuickSync,
    required this.onRecycle,
    this.onQuickNote,
    required this.onMenu,
    required this.hasSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 6, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heading = Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          );
          final actions = [
            IconButton(
                tooltip: l.quickNote,
                onPressed: onQuickNote,
                icon: const Icon(Icons.sticky_note_2_outlined)),
            IconButton(
                tooltip: l.quickSync,
                onPressed: onQuickSync == null
                    ? null
                    : () => unawaited(onQuickSync!.call()),
                icon: const Icon(Icons.sync_rounded)),
            IconButton(
                tooltip: l.recycleBin,
                onPressed: onRecycle,
                icon: const Icon(Icons.delete_outline_rounded)),
          ];
          final menu = PopupMenuButton<String>(
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
          );
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [Expanded(child: heading), menu]),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ],
            );
          }
          return Row(
            children: [Expanded(child: heading), ...actions, menu],
          );
        },
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
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          SizedBox(
            width: constraints.maxWidth < 400
                ? constraints.maxWidth
                : (constraints.maxWidth - 8) / 2,
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
                    child:
                        Text(l.sortByTitle, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) {
                if (value != null) onSortChanged(value);
              },
            ),
          ),
          SizedBox(
            width: constraints.maxWidth < 400
                ? constraints.maxWidth
                : (constraints.maxWidth - 8) / 2,
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
      ),
    );
  }
}

class _SearchEmpty extends StatelessWidget {
  final AppLocalizations l;
  final VoidCallback onClear;
  const _SearchEmpty({required this.l, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off_rounded,
            size: 40, color: scheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(l.searchNoResultTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(l.searchNoResultSubtitle,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear_rounded, size: 18),
          label: Text(l.clearSearch),
        ),
      ]),
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
          l.emptyInboxSubtitleHint
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
    final l = AppLocalizations.of(context);
    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final content = _TaskContent(
                task: task,
                done: done,
                l: l,
                scheme: scheme,
                showMetadataBelow: compact,
                metadata: _TaskMetadata(
                  task: task,
                  l: l,
                  scheme: scheme,
                ),
                formatDue: _fmt,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: _statusColor(scheme), shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  _TaskToggle(
                    taskId: task.id,
                    done: done,
                    scheme: scheme,
                    onToggle: onToggle,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: content),
                  if (!compact) ...[
                    const SizedBox(width: 8),
                    _TaskMetadata(task: task, l: l, scheme: scheme),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _fmt(DueDate due, AppLocalizations l) {
    final d = due.dateOnly ? due.value.toUtc() : due.value.toLocal();
    final date = l.dateMonthDay(d.day, d.month);
    if (due.dateOnly) return date;
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$date $h:$min';
  }
}

class _TaskToggle extends StatelessWidget {
  final String taskId;
  final bool done;
  final ColorScheme scheme;
  final ValueChanged<bool> onToggle;

  const _TaskToggle({
    required this.taskId,
    required this.done,
    required this.scheme,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey('task-toggle-$taskId'),
      width: 48,
      height: 48,
      child: Semantics(
        button: true,
        toggled: done,
        onTap: () => onToggle(!done),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onToggle(!done),
          child: Center(
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? scheme.tertiary : Colors.transparent,
                border: Border.all(
                    color: done ? scheme.tertiary : scheme.outline, width: 1.6),
              ),
              child: done
                  ? Icon(Icons.check, size: 14, color: scheme.onTertiary)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskContent extends StatelessWidget {
  final Task task;
  final bool done;
  final AppLocalizations l;
  final ColorScheme scheme;
  final bool showMetadataBelow;
  final Widget metadata;
  final String Function(DueDate, AppLocalizations) formatDue;

  const _TaskContent({
    required this.task,
    required this.done,
    required this.l,
    required this.scheme,
    required this.showMetadataBelow,
    required this.metadata,
    required this.formatDue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                decoration: done ? TextDecoration.lineThrough : null)),
        if (task.status == TaskStatus.doing) ...[
          const SizedBox(height: 5),
          Container(
            key: const ValueKey('doing-badge'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(l.doing,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer)),
          ),
        ],
        if (task.due != null) ...[
          const SizedBox(height: 5),
          Row(children: [
            Icon(Icons.schedule_rounded,
                size: 13, color: scheme.onSurfaceVariant),
            const SizedBox(width: 3),
            Flexible(
              child: Text(formatDue(task.due!, l),
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
          ]),
        ],
        if (showMetadataBelow && _hasMetadata(task)) ...[
          const SizedBox(height: 4),
          metadata,
        ],
      ],
    );
  }

  bool _hasMetadata(Task task) =>
      task.isRepeating || task.priority > 0 || task.due != null;
}

class _TaskMetadata extends StatelessWidget {
  final Task task;
  final AppLocalizations l;
  final ColorScheme scheme;

  const _TaskMetadata({
    required this.task,
    required this.l,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (task.isRepeating)
          Tooltip(
            message: l.repeatRule,
            child: Icon(Icons.repeat_rounded, size: 16, color: scheme.primary),
          ),
        if (task.priority > 0)
          Tooltip(
            message: _priorityBadgeLabel(task.priority, l),
            child: Icon(Icons.flag_rounded,
                size: 15, color: _priorityBadgeColor(task.priority, scheme)),
          ),
        if (task.due != null) _DueChip(due: task.due!),
      ],
    );
  }

  String _priorityBadgeLabel(int priority, AppLocalizations l) =>
      switch (priority) {
        3 => l.priorityHigh,
        2 => l.priorityMedium,
        1 => l.priorityLow,
        _ => '',
      };

  Color _priorityBadgeColor(int priority, ColorScheme scheme) =>
      switch (priority) {
        3 => scheme.error,
        2 => Colors.orange.shade700,
        _ => scheme.onSurfaceVariant,
      };
}

class _DueChip extends StatelessWidget {
  final DueDate due;
  const _DueChip({required this.due});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final local = due.dateOnly ? due.value.toUtc() : due.value.toLocal();
    final comparisonNow =
        due.dateOnly ? DateTime.utc(now.year, now.month, now.day) : now;
    final overdue = due.dateOnly
        ? local.isBefore(comparisonNow)
        : local.isBefore(comparisonNow);
    final urgent = overdue ||
        (!due.dateOnly && local.difference(comparisonNow).inDays == 0) ||
        (due.dateOnly &&
            local.year == comparisonNow.year &&
            local.month == comparisonNow.month &&
            local.day == comparisonNow.day);
    // 仅展示有信息量的状态；普通"有期限"与左侧时间重复，不再显示
    if (!overdue && !urgent) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final color = overdue ? scheme.error : scheme.primary;
    return Text(overdue ? l.overdue : l.today,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color));
  }
}
