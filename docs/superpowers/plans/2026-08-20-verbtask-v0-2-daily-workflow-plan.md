# VerbTask v0.2 日常工作流实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有 VerbTask 原型推进为可日常使用的 Android + Windows 个人任务工具，完成清单、系统视图、完整编辑、搜索筛选、提醒语义、LLM 解析接线和中英双语。

**Architecture:** 保留当前 Flutter StatefulWidget + service + repository 分层和 JSON 文件存储。业务写入统一经过 `TaskService` 或 `ListService`，UI 不直接操作仓库；v0.2 只修正 JSON 写入安全和本地工作流，LAN 增量同步与认证单独进入 v0.3。

**Tech Stack:** Flutter 3.47、Dart 3.13、JSON 文件仓库、`uuid`、`rrule`、`flutter_local_notifications`、`workmanager`、`flutter_localizations`。

**Spec:** `docs/superpowers/specs/2026-08-20-verbtask-v0-2-daily-workflow-design.md`

## Global Constraints

- 保留 JSON 本地存储；不得在本计划中迁移 SQLite/Drift。
- 所有用户可见文本必须来自 `lib/l10n/app_zh.arb` 或 `lib/l10n/app_en.arb`。
- 解析结果必须在确认后才创建任务；LLM 失败必须回退本地解析。
- `dateOnly` 与 UTC 序列化字段名保持兼容；新增字段必须有旧数据默认值。
- 任务写入必须继续通过 repository；UI 不直接调用 `upsertTask`。
- 业务逻辑先写失败测试，再写最小实现；每个任务完成后运行对应测试和全量测试。
- 本阶段不把未经认证的 LAN HTTP 同步标记为已完成安全同步。

---

### Task 1: JSON 安全基线与清单 CRUD

**Files:**
- Modify: `lib/core/models/task.dart`
- Modify: `lib/core/models/task_list.dart`
- Modify: `lib/core/storage/repository.dart`
- Modify: `lib/core/storage/file_repository.dart`
- Modify: `lib/core/storage/inmemory_repository.dart`
- Modify: `lib/core/services/task_service.dart`
- Test: `test/storage_test.dart`
- Test: `test/task_service_test.dart`

**Interfaces:**
- `TaskService.createList({required String name, String? color}) -> Future<TaskList>`
- `TaskService.editList(TaskList list, {String? name, String? color, int? sortOrder}) -> Future<TaskList>`
- `TaskService.deleteList(TaskList list) -> Future<void>`；先将该清单下任务移动到收件箱，再删除清单。
- `TaskRepository.removeList(String id) -> Future<void>`
- `Task.copyWith` 每次变更生成 UUID `changeId`；旧 JSON 缺失 changeId 时继续读取。

- [ ] **Step 1: Write the failing tests**

```dart
test('删除清单会把任务移回收件箱并移除清单', () async {
  final repo = InMemoryRepository();
  final service = TaskService(repo);
  final list = await service.createList(name: '工作');
  await service.create(title: '报告', listId: list.id);

  await service.deleteList(list);

  expect((await repo.allLists()), isEmpty);
  expect((await repo.allTasks()).single.listId, isNull);
});

test('任务编辑生成新的唯一 changeId', () async {
  final service = TaskService(InMemoryRepository());
  final task = await service.create(title: '原任务');
  final edited = await service.edit(task, title: '新任务');
  expect(edited.changeId, isNot(task.changeId));
});
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/task_service_test.dart test/storage_test.dart`

Expected: FAIL because list service methods and repository list deletion do not exist, and `changeId` is currently deterministic.

- [ ] **Step 3: Implement the minimal repository and service changes**

Add `removeList` to both repository implementations, add list operations to `TaskService`, and update `copyWith`/service writes to use UUID change IDs. In `FileRepository._persist`, write JSON to a sibling temporary file, replace the target only after the temporary write completes, and keep the original file when serialization or writing fails.

- [ ] **Step 4: Run focused and full tests**

Run: `flutter test test/task_service_test.dart test/storage_test.dart`

Expected: PASS.

Run: `flutter test`

Expected: all existing tests plus the new list/changeId tests pass.

- [ ] **Step 5: Commit the isolated data baseline**

```bash
git add lib/core/models lib/core/storage lib/core/services test/task_service_test.dart test/storage_test.dart
git commit -m "feat: harden local data and add list CRUD"
```

### Task 2: Settings state、提醒语义与系统权限状态

**Files:**
- Modify: `lib/core/settings/local_settings.dart`
- Modify: `lib/core/settings/settings_controller.dart`
- Modify: `lib/core/notifications/reminder_scheduler.dart`
- Modify: `lib/core/notifications/reminder_service.dart`
- Modify: `lib/core/notifications/app_notifications.dart`
- Modify: `lib/core/notifications/platform_notification_sink.dart`
- Test: `test/reminder_settings_test.dart`
- Create: `test/reminder_scheduler_test.dart`

**Interfaces:**
- `ReminderService.syncReminders({DateTime? now, int? defaultOffsetMinutes}) -> Future<void>`；`null` 表示关闭全局默认提醒，非空值为有符号偏移（负数提前，`0` 到期提醒）。
- `SettingsController.themeMode -> ThemeMode` and setter persisted through `LocalSettings`.
- `SettingsController.notifyDefaultReminderEnabled` 独立持久化；默认开启，`notifyDefaultOffsetMin` 默认 `-30`。
- `AppNotifications.rescheduleAll(repo, {int? defaultOffsetMinutes})` cancels old scheduled notifications before rebuilding。

- [ ] **Step 1: Write the failing tests**

```dart
test('无单条提醒时使用全局提前量', () async {
  final repo = InMemoryRepository();
  final tasks = TaskService(repo);
  await tasks.create(title: '会议', due: DueDate(DateTime.utc(2026, 1, 10, 9)));
  final sink = LoggingNotificationSink();

  await ReminderService(tasks: tasks, sink: sink)
      .syncReminders(now: DateTime.utc(2026, 1, 1), defaultOffsetMinutes: -30);

  expect(sink.scheduled.single.at, DateTime.utc(2026, 1, 10, 8, 30));
});

test('重复任务从截止时间而不是创建时间展开', () {
  final task = Task(
    id: 'repeat', title: '打卡', rrule: 'FREQ=DAILY',
    due: DueDate(DateTime.utc(2026, 1, 10, 9)),
    createdAt: DateTime.utc(2025, 1, 1), updatedAt: DateTime.utc(2025, 1, 1),
  );
  final next = ReminderScheduler().nextDueForRepeating(
    task, DateTime.utc(2026, 1, 10, 10), RruleService());
  expect(next, DateTime.utc(2026, 1, 11, 9));
});
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/reminder_settings_test.dart test/reminder_scheduler_test.dart`

Expected: FAIL because the default offset is ignored and repeating schedules start at `createdAt`.

- [ ] **Step 3: Implement the reminder contract**

Use the task reminders when non-empty; otherwise synthesize one relative reminder from the global offset when a due date exists. Use `task.due.value` as the RRULE start. Call `cancelAll` before rebuilding schedules. Add a persisted `themeMode` setting and expose it through `SettingsController`.

- [ ] **Step 4: Add platform permission hooks without blocking saves**

Request Android 13 notification permission during notification initialization when the plugin supports it. Keep exact scheduling capability behind a permission check; if unavailable, retain the safe inexact schedule and surface the status through the settings controller rather than throwing from task CRUD.

- [ ] **Step 5: Run focused and full tests**

Run: `flutter test test/reminder_settings_test.dart test/reminder_scheduler_test.dart && flutter test`

Expected: PASS.

### Task 3: 完整本地化与设置页状态

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Regenerate: `lib/l10n/generated/app_localizations*.dart`
- Modify: `lib/app.dart`
- Modify: `lib/ui/home_page.dart`
- Modify: `lib/ui/pages/task_edit_page.dart`
- Modify: `lib/ui/pages/settings_page.dart`
- Modify: `lib/ui/pages/recycle_bin_page.dart`
- Test: `test/widget_test.dart`
- Test: `test/ui_pages_test.dart`

**Interfaces:**
- Generated `AppLocalizations` exposes the same keys in English and Chinese for navigation, task fields, status, filters, reminders, errors, and empty states.
- `SettingsPage` receives `ThemeMode themeMode` and reports the selected value through `onThemeModeChanged`.

- [ ] **Step 1: Add localization keys and failing locale tests**

Add keys for `today`, `planned`, `allTasks`, `board`, `newList`, `searchTasks`, `sortByDue`, `sortByCreated`, `filter`, `taskTitle`, `notes`, `dueDate`, `dateOnly`, `reminder`, `repeat`, `priority`, `status`, `save`, `cancel`, `confirm`, `noTasks`, `overdue`, `todayLabel`, `settings`, and all existing page-specific copy in both ARB files. Add widget assertions that an English edit/settings/recycle flow contains no Chinese page labels.

- [ ] **Step 2: Run generation and verify the new tests fail for the current hard-coded strings**

Run: `flutter gen-l10n; flutter test test/widget_test.dart test/ui_pages_test.dart`

Expected: FAIL until pages use `AppLocalizations` instead of literal Chinese strings and SettingsPage reflects the actual ThemeMode.

- [ ] **Step 3: Replace visible literals and thread locale/theme state**

Pass `themeMode` from `_VerbAppState` to `HomePage` and `SettingsPage`, use `AppLocalizations.of(context)` in every page, and replace hard-coded date/status labels with localized strings. Keep tooltips localized too.

- [ ] **Step 4: Run generation, analyze, and focused tests**

Run: `flutter gen-l10n; dart format lib/l10n lib/app.dart lib/ui; flutter analyze; flutter test test/widget_test.dart test/ui_pages_test.dart`

Expected: no analyzer issues and focused locale tests pass.

### Task 4: 清单、系统视图、搜索筛选与看板 UI

**Files:**
- Modify: `lib/core/services/task_service.dart`
- Modify: `lib/ui/home_page.dart`
- Create: `lib/ui/pages/list_manage_page.dart`
- Create: `lib/ui/pages/board_page.dart`
- Test: `test/task_service_test.dart`
- Test: `test/ui_pages_test.dart`
- Create: `test/home_query_test.dart`

**Interfaces:**
- Extend `BySort` with `titleAsc` while preserving `dueAsc` and `createdDesc`.
- Extend `TaskService.query` with `DateTime? dueFrom`, `DateTime? dueTo`, and `bool includeDone` filters; callers derive local-day boundaries and pass UTC instants, with `dueTo` exclusive. The query layer compares stored UTC values without applying a second timezone conversion.
- `HomePage` keeps quick add separate from search and exposes a `ViewFilter` state for `inbox`, `today`, `planned`, `list`, `done`, and `board`.

- [ ] **Step 1: Write failing query and widget tests**

```dart
test('today filter returns due tasks on the local calendar day and overdue tasks', () async {
  final service = TaskService(InMemoryRepository());
  await service.create(title: '今天', due: DueDate(DateTime.utc(2026, 1, 10, 9)));
  await service.create(title: '明天', due: DueDate(DateTime.utc(2026, 1, 11, 9)));
  // HomePage 的本地 2026-01-10 日边界已转换成 UTC；dueTo 为排他上界。
  final result = await service.query(
    dueFrom: DateTime.utc(2026, 1, 1),
    dueTo: DateTime.utc(2026, 1, 11),
  );
  expect(result.map((t) => t.title), contains('今天'));
  expect(result.map((t) => t.title), isNot(contains('明天')));
});
```

Add widget tests that search does not open the NLP confirmation dialog, that a list can be selected, and that the board renders the three localized status columns.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/task_service_test.dart test/home_query_test.dart test/ui_pages_test.dart`

Expected: FAIL because the query boundaries, list management page, separate search field, and board view do not exist.

- [ ] **Step 3: Implement query filters and list management**

Add the named query parameters and sort option. Build `ListManagePage` on `TaskService.createList/editList/deleteList`; confirm list deletion before moving tasks to Inbox. Keep the current single-column mobile visual language and avoid nested cards.

- [ ] **Step 4: Implement Home navigation and board**

Replace the current three hard-coded tabs with localized system views. Add a search mode in the app bar, a sort/filter menu, list selection, and a board entry. `BoardPage` renders `todo`, `doing`, and `done` columns using the same task row component and calls `TaskService.edit` when a status action is chosen.

- [ ] **Step 5: Run focused tests and inspect a populated emulator screen**

Run: `flutter test test/task_service_test.dart test/home_query_test.dart test/ui_pages_test.dart; flutter analyze`

Then run `flutter build apk --debug`, install it on `emulator-5554`, and verify the empty state, a populated list, search, list creation, and board layout at a mobile viewport.

### Task 5: 完整任务编辑与三级 NLP 录入

**Files:**
- Modify: `lib/ui/pages/task_edit_page.dart`
- Modify: `lib/ui/home_page.dart`
- Modify: `lib/core/nlp/nlp_service.dart`
- Modify: `lib/core/nlp/llm_client.dart`
- Modify: `lib/core/settings/settings_controller.dart`
- Test: `test/ui_pages_test.dart`
- Test: `test/nlp_test.dart`
- Test: `test/llm_client_test.dart`

**Interfaces:**
- `TaskEditPage` accepts the current `TaskService` and optional `TaskList` collection, and saves `due`, `listId`, `reminders`, `priority`, `status`, and `rrule` through `TaskService.edit`.
- `LlmDraft` includes optional `dateOnly`; `NlpService.parse` accepts `LlmConfig?` and returns `NlpResult.source` as `local` or `llm`; errors return the local result without throwing to UI.

- [ ] **Step 1: Write failing editor and LLM-flow tests**

Add a widget test that changes due date mode, reminder offset, priority, and list then verifies the repository task. Add a test that a configured LLM result is used, and a test that a failed LLM call falls back to local parsing.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/ui_pages_test.dart test/nlp_test.dart test/llm_client_test.dart`

Expected: FAIL because the editor does not render or save these fields and Home always calls `parseLocal`.

- [ ] **Step 3: Implement the editor**

Add date/date-only controls, reminder enable/offset controls, list dropdown, priority menu, and RRULE field. Use a compact section layout and localized labels. After saving, call notification rescheduling from the parent.

- [ ] **Step 4: Connect configured LLM parsing**

Construct `NlpService(llm: LlmClient())` when available, read `SettingsController.llmEnabled/baseUrl/llmKey`, show a localized data-outside-device notice before the request, and display the unified confirmation dialog for both local and LLM results. Keep manual title entry as the fallback.

- [ ] **Step 5: Run focused and full tests**

Run: `flutter test test/ui_pages_test.dart test/nlp_test.dart test/llm_client_test.dart; flutter analyze; flutter test`

### Task 6: 备份、发布基线与最终验收

**Files:**
- Modify: `lib/core/storage/backup_service.dart`
- Modify: `lib/core/settings/settings_controller.dart`
- Modify: `lib/ui/pages/settings_page.dart`
- Modify: `README.md`
- Create: `LICENSE`
- Test: `test/storage_test.dart`
- Test: `test/settings_page_test.dart`

**Interfaces:**
- `BackupService.exportCsv()` and `BackupService.importCsv(String)` use a documented stable header: `id,title,notes,listId,status,due,dateOnly,priority,rrule,deleted`.
- JSON import rejects wrong `format` or unsupported future versions without mutating the repository.

- [ ] **Step 1: Write failing backup validation tests**

Test CSV round-trip for title/notes/status/due and test that invalid JSON format leaves a pre-existing task untouched.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/storage_test.dart test/settings_page_test.dart`

Expected: FAIL because CSV and preflight validation do not exist.

- [ ] **Step 3: Implement backup/export UX and project metadata**

Add CSV conversion with RFC-style quoted fields, validate the JSON version before any writes, document the export formats in Settings, add MIT `LICENSE`, and replace the starter `README.md` with Android/Windows setup and local-data notes.

- [ ] **Step 4: Run the complete verification matrix**

Run:

```bash
flutter gen-l10n
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build windows
git diff --check
```

Expected: all commands succeed; Android debug APK and Windows executable are produced. Perform one emulator smoke pass for Chinese and English, quick add confirmation, search, list CRUD, editor, board, theme, and settings.

- [ ] **Step 5: Commit the v0.2 implementation**

```bash
git add lib test android README.md LICENSE docs
git commit -m "feat: complete v0.2 daily task workflow"
```
