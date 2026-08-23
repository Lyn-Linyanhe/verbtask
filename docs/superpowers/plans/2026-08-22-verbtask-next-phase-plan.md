# VerbTask 下一阶段可靠性与体验实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 VerbTask 从“功能和测试基本齐全”推进到数据不静默丢失、提醒/同步语义可验证、Android/Windows 真实体验可验收、发布产物可重复构建的状态。

**Architecture:** 保留当前 Flutter + StatefulWidget/Controller + JSON Repository 架构，先在现有边界内修复安全性和可验证性。NLP 使用本地解析作为明确词法字段的底线，LLM 作为补充；同步统一使用任务级 LWW；通知调度、同步和存储都通过可注入接口测试，平台行为通过模拟器/Windows Release 冒烟验证。

**Tech Stack:** Flutter 3.47.0、Dart 3.13.0、`flutter_local_notifications`、WorkManager、`rrule`、`tray_manager`、`window_manager`、Inno Setup、GitHub Actions。

**Spec:** `docs/下一阶段调研报告-2026-08-22.md`、`docs/方案设计.md`、`docs/superpowers/specs/2026-08-20-verbtask-v0-3-lan-sync-design.md`

## Global Constraints

- Android 优先，继续支持 Windows；不引入账号和云端同步。
- 任务文本只有用户开启 LLM 并确认后才发送到用户填写的 OpenAI 兼容接口。
- 同步冲突继续采用任务级 Last-write-wins，比较规则必须在客户端和服务端一致。
- 所有行为变更先写会失败的测试；不得用放宽断言或静默吞错使测试变绿。
- 不在仓库提交 API key、Android release keystore 或 Windows 代码签名私钥。
- 保留 JSON 旧数据的可读性；任何迁移失败都必须保留原文件并给出恢复路径。
- 完成新版本前，`flutter analyze`、`flutter test`、Android/Windows release 构建和对应平台冒烟必须有记录。

---

### Task 1: 建立可靠的测试门禁

**Files:**
- Create: `.github/workflows/verify.yml`
- Create: `tool/check_test_output.dart`
- Modify: `test/board_date_format_test.dart`
- Modify: `test/board_drag_test.dart`
- Modify: `test/priority_badge_test.dart`
- Test: existing full suite

**Interfaces:**
- CI consumes the repository's Flutter version and emits non-zero status on format, analyze, test, or build failure.
- Tests must not emit hit-test warnings for the fixed navigation flow.

- [ ] **Step 1: Replace missed text taps with semantic, visible targets.**

Use the actual navigation control finder, scroll it into view when necessary, and assert `hitTestable()` before tapping. Do not use `warnIfMissed: false`.

- [ ] **Step 2: Run the affected tests and verify the warning is still reproduced before the fix.**

Run:

```powershell
flutter test test/board_date_format_test.dart test/board_drag_test.dart test/priority_badge_test.dart
```

Expected before the test changes: tests pass with the existing `tap()` hit-test warning.

- [ ] **Step 3: Add a CI workflow with deterministic checks.**

The workflow must run `flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and the platform build jobs that are available on the runner. Network LLM tests remain opt-in and must not run with a real key in CI.

- [ ] **Step 4: Run the fixed tests and the full suite.**

Run:

```powershell
flutter test test/board_date_format_test.dart test/board_drag_test.dart test/priority_badge_test.dart
flutter analyze --no-pub
flutter test
```

Expected: all tests pass and no hit-test warning is printed.

- [ ] **Step 5: Commit the gate changes.**

```powershell
git add .github test/board_date_format_test.dart test/board_drag_test.dart test/priority_badge_test.dart
git commit -m "test: 建立可靠测试门禁"
```

### Task 2: Fix NLP field-level merging and deterministic Chinese intent

**Files:**
- Modify: `lib/core/nlp/nlp_service.dart`
- Modify: `lib/core/nlp/zh_parser.dart`
- Modify: `test/reminder_extraction_test.dart`
- Modify: `test/nlp_test.dart`
- Modify: `tool/llm_mass_probe.dart`
- Test: `test/nlp_field_merge_test.dart`

**Interfaces:**
- `NlpService.parse` continues returning `NlpResult`.
- Local parsing supplies explicit `rrule` and reminder intent; LLM may fill fields that local parsing leaves unknown.
- The case runner exits non-zero when a declared expected field does not match.

- [ ] **Step 1: Add failing field-merge tests.**

Use a `MockClient` response with a valid title and null structured fields. Assert that local explicit fields survive:

```dart
test('LLM 漏字段时保留本地明确的重复和提醒', () async {
  final result = await serviceWithJson(
    input: '每隔2天提前30分钟浇花',
    json: {'title': '浇花', 'due': null, 'dateOnly': true,
      'rrule': null, 'priority': 0, 'reminderMinutes': null},
  );
  expect(result.rrule, contains('FREQ=DAILY;INTERVAL=2'));
  expect(result.reminderMinutes, 30);
});
```

Also add cases for `通知我`, `别忘了`, `不用提醒我`, `每两周`, and `每个周末`.

- [ ] **Step 2: Run the new tests and verify they fail for the missing merge/intent behavior.**

Run:

```powershell
flutter test test/nlp_field_merge_test.dart test/reminder_extraction_test.dart test/nlp_test.dart
```

Expected: the new assertions fail because current LLM results are adopted without field-level merge and current negation/recurrence rules are incomplete.

- [ ] **Step 3: Implement the minimum merge policy.**

Parse local text once when an LLM result is available. Use local values for explicit reminder and recurrence signals; use LLM values when local parsing has no value; preserve the existing LLM title/due/priority behavior with the existing safety nets. Add explicit negative-reminder detection before positive keyword detection. Extend the local recurrence parser for Chinese numeral intervals, `隔天/隔周`, `两周一次`, and weekend expressions.

- [ ] **Step 4: Make the case runner compare expectations.**

Parse the existing case expectation fields into typed checks for title, due/dateOnly, rrule, priority, reminder, source, and fallback. Print a failure with case id and actual value, then exit with a non-zero code.

- [ ] **Step 5: Run the focused and full tests.**

```powershell
flutter test test/nlp_field_merge_test.dart test/reminder_extraction_test.dart test/nlp_test.dart
flutter analyze --no-pub
flutter test
```

- [ ] **Step 6: Commit the NLP fix.**

```powershell
git add lib/core/nlp test/nlp_field_merge_test.dart test/nlp_test.dart test/reminder_extraction_test.dart tool/llm_mass_probe.dart
git commit -m "fix(nlp): 合并本地提醒与重复语义"
```

### Task 3: Protect local data and add schema migration

**Files:**
- Modify: `lib/core/storage/file_repository.dart`
- Modify: `lib/core/storage/repository.dart`
- Modify: `lib/core/storage/backup_service.dart`
- Modify: `lib/core/settings/local_settings.dart`
- Modify: `test/storage_test.dart`
- Create: `test/storage_recovery_test.dart`

**Interfaces:**
- Add a typed `StorageLoadException` carrying the original file path and quarantined recovery path.
- File schema has an explicit current version constant and a migration function from every supported older version.
- Backup import validates the entire decoded snapshot before changing the repository.

- [ ] **Step 1: Add failing corruption, future-version, migration, and atomic-import tests.**

Cover malformed JSON, a valid root with one invalid task, an unsupported future version, an import with a valid first record and invalid second record, and a successful old-version migration. Assert that the original file and pre-import repository remain unchanged on failure.

- [ ] **Step 2: Run the tests and verify current silent-reset/partial-import failures.**

```powershell
flutter test test/storage_recovery_test.dart test/storage_test.dart
```

- [ ] **Step 3: Implement quarantine and typed failure.**

On load failure, leave the original JSON untouched, move/copy a recoverable diagnostic snapshot to a timestamped sibling, and surface the typed failure to the application bootstrap. Never persist an empty repository as a replacement for an unreadable file.

- [ ] **Step 4: Implement versioned migration and atomic import.**

Decode and validate all records into a temporary in-memory snapshot, migrate it, then replace repository state with one persistence operation. Unsupported future versions must be rejected without mutation.

- [ ] **Step 5: Run storage tests and full static checks.**

```powershell
flutter test test/storage_recovery_test.dart test/storage_test.dart
flutter analyze --no-pub
```

- [ ] **Step 6: Commit the storage changes.**

```powershell
git add lib/core/storage lib/core/settings/local_settings.dart test/storage_test.dart test/storage_recovery_test.dart
git commit -m "fix(storage): 防止损坏数据静默丢失"
```

### Task 4: Make sync authentication and conflict resolution authoritative

**Files:**
- Modify: `lib/core/sync/http_transport.dart`
- Modify: `lib/core/sync/conflict_resolver.dart`
- Modify: `lib/core/sync/sync_engine.dart`
- Modify: `lib/core/sync/sync_host.dart`
- Modify: `test/http_transport_test.dart`
- Modify: `test/sync_engine_test.dart`

**Interfaces:**
- Production `SyncServer` rejects an empty token; test-only transports explicitly opt into insecure mode.
- Server and client use the same conflict comparator for task versions.
- Server returns a diagnostic response for rejected stale changes without mutating the current task.

- [ ] **Step 1: Add failing auth and stale-push tests.**

Start a server with no production token and assert `/pull`/`/push` return 401. Add a server task with a newer version and push an older task with a fresh change ID; assert the newer task remains.

- [ ] **Step 2: Run the focused tests and verify current failures.**

```powershell
flutter test test/http_transport_test.dart test/sync_engine_test.dart
```

- [ ] **Step 3: Implement mandatory authentication and shared LWW comparison.**

Use a required token in `SyncHost`; have test fixtures pass an explicit test token or a dedicated test server option. Before `upsertTask`, compare incoming and existing tasks with the same `(version, updatedAt, changeId)` ordering used by `ConflictResolver`.

- [ ] **Step 4: Add deletion and stale-result assertions.**

Verify an older tombstone cannot resurrect a newer task and a duplicate change ID is idempotent.

- [ ] **Step 5: Run sync tests and static analysis.**

```powershell
flutter test test/http_transport_test.dart test/sync_engine_test.dart test/sync_pairing_test.dart
flutter analyze --no-pub
```

- [ ] **Step 6: Commit the sync trust fixes.**

```powershell
git add lib/core/sync test/http_transport_test.dart test/sync_engine_test.dart
git commit -m "fix(sync): 强制鉴权并统一冲突判定"
```

### Task 5: Repair notification identity, rescheduling, and Android retry behavior

**Files:**
- Modify: `lib/core/notifications/reminder_service.dart`
- Modify: `lib/core/notifications/platform_notification_sink.dart`
- Modify: `lib/core/notifications/app_notifications.dart`
- Modify: `lib/core/notifications/reminder_scheduler.dart`
- Modify: `lib/core/sync/background_sync.dart`
- Modify: `lib/main.dart`
- Modify: `test/notification_open_task_test.dart`
- Modify: `test/reminder_scheduler_test.dart`
- Modify: `test/reminder_settings_test.dart`
- Create: `test/notification_identity_test.dart`

**Interfaces:**
- Notification payload is a stable task identifier (and later an occurrence identifier), never the display/scheduling ID.
- Task mutations call one rescheduling entry point.
- Background sync returns failure for retryable errors and does not report success after swallowing an exception.

- [ ] **Step 1: Add failing payload, edit-reschedule, opt-out, and background-failure tests.**

Assert that a scheduled notification payload equals `task.id`, that global default plus explicit task opt-out produces no notification, that editing a due/reminder cancels the old schedule, and that a failed background sync returns a retryable failure.

- [ ] **Step 2: Run focused tests and verify current failures.**

```powershell
flutter test test/notification_identity_test.dart test/notification_open_task_test.dart test/reminder_scheduler_test.dart test/reminder_settings_test.dart
```

- [ ] **Step 3: Separate notification ID from payload and wire rescheduling.**

Use a deterministic integer scheduling ID derived from task/occurrence data and pass only the task ID to navigation. Call rescheduling after create, edit, complete, delete, restore, and import through the existing notification facade.

- [ ] **Step 4: Add an explicit task reminder policy.**

Represent inherited default, explicitly enabled, and explicitly disabled states without treating an empty reminder list as both “inherit” and “disable”. Migrate old tasks to inherit.

- [ ] **Step 5: Make background failure visible to WorkManager.**

Return `false` or throw for transient network/discovery failures, keep permanent configuration errors diagnosable, and expose the last sync failure to the UI. Keep notification rescheduling independent from successful LAN sync.

- [ ] **Step 6: Run tests and Android debug build.**

```powershell
flutter test test/notification_identity_test.dart test/notification_open_task_test.dart test/reminder_scheduler_test.dart test/reminder_settings_test.dart
flutter build apk --debug
```

- [ ] **Step 7: Commit notification and background fixes.**

```powershell
git add lib/core/notifications lib/core/sync/background_sync.dart lib/main.dart test/notification_identity_test.dart test/notification_open_task_test.dart test/reminder_scheduler_test.dart test/reminder_settings_test.dart
git commit -m "fix(notify): 修复通知定位并补齐后台失败语义"
```

### Task 6: Make Android layouts and platform behavior testable

**Files:**
- Modify: `lib/ui/home_page.dart`
- Modify: `lib/ui/pages/settings_page.dart`
- Modify: `lib/ui/pages/task_edit_page.dart`
- Modify: `lib/ui/pages/board_page.dart`
- Modify: `lib/core/notifications/reminder_service.dart`
- Modify: `lib/core/notifications/platform_notification_sink.dart`
- Modify: `test/ui_pages_test.dart`
- Create: `test/mobile_layout_test.dart`
- Modify: `docs/Android-专项审查-2026-08-21.md`

**Interfaces:**
- Phone layouts remain scrollable at 320/360dp and text scales 1.0/1.3/2.0 without RenderFlex overflow.
- Completion controls expose at least a 48dp semantic hit target while retaining the small visual icon.
- Notification copy follows the current locale; settings state exact-alarm availability, explain that `exactAllowWhileIdle` is used when available, and state that the `inexactAllowWhileIdle` fallback may drift.

- [ ] **Step 1: Add failing narrow-layout tests.**

Build the key pages at 320dp and 360dp with text scale 1.0, 1.3, and 2.0. Assert no overflow exception, theme controls remain reachable, dropdown labels ellipsize, and the completion control is hit-testable through its full semantic area.

- [ ] **Step 2: Run the tests and verify current layout risks.**

```powershell
flutter test test/mobile_layout_test.dart
```

- [ ] **Step 3: Implement responsive layouts.**

Use `Wrap` or breakpoint-based vertical layout for header/filter/settings rows, `isExpanded: true` and ellipsis for dropdowns, responsive board column widths, and 48dp semantic wrappers for small controls. Do not remove information; make it scroll or wrap.

- [ ] **Step 4: Verify Android permission and notification copy behavior.**

Use localized channel/body strings and an explicit settings status for denied notification permission. Keep `SCHEDULE_EXACT_ALARM` and document the actual policy: use `exactAllowWhileIdle` when the capability probe succeeds, and `inexactAllowWhileIdle` otherwise; expose both notification and exact-alarm status in settings.

- [ ] **Step 5: Run Android emulator checks.**

```powershell
flutter build apk --debug
flutter test integration_test -d <API35-device>
adb shell am force-stop com.verbapp.verb_app
adb shell input keyevent KEYCODE_HOME
adb shell dumpsys deviceidle force-idle
```

Save screenshots and logcat for launch, keyboard, notification, force-stop, Doze, and recovery. Do not mark the document complete without these artifacts.

- [ ] **Step 6: Commit mobile layout changes after emulator verification.**

```powershell
git add lib/ui test/mobile_layout_test.dart lib/core/notifications docs/Android-专项审查-2026-08-21.md
git commit -m "fix(android): 完善窄屏布局与后台体验"
```

### Task 7: Implement incremental sync, tombstones, migration, and status feedback

**Files:**
- Modify: `lib/core/sync/http_transport.dart`
- Modify: `lib/core/sync/sync_engine.dart`
- Modify: `lib/core/sync/sync_controller.dart`
- Modify: `lib/core/sync/background_sync.dart`
- Modify: `lib/core/models/task_list.dart`
- Modify: `lib/core/storage/file_repository.dart`
- Modify: `lib/core/settings/local_settings.dart`
- Modify: `lib/ui/pages/settings_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/http_transport_test.dart`, `test/sync_engine_test.dart`, `test/storage_recovery_test.dart`

**Interfaces:**
- `/pull?after=<cursor>` returns changes and a next cursor; the client persists the cursor only after applying the payload successfully.
- Applied change IDs are deduplicated across repeated pulls and restarts.
- Lists and permanent deletes have explicit tombstone semantics so deleted objects do not reappear.
- Settings expose last sync time, status, and actionable failure text.

- [ ] **Step 1: Add failing cursor, idempotency, tombstone, interval, and UI-state tests.**

Use two in-memory repositories and a persisted settings fixture. Assert the second pull contains only changes after the first cursor, duplicate pull does not append changes, deleted lists do not reappear, and setting 120 minutes changes the registered interval argument.

- [ ] **Step 2: Implement cursor/change payload and persistent metadata.**

Keep backward compatibility with the version-1 file via the migration from Task 3. Advance the cursor only after all remote changes are applied and local changes are safely pushed.

- [ ] **Step 3: Add list and permanent-delete tombstones.**

Extend the serialized model with deleted metadata and use the same LWW comparator. Keep the recycle-bin behavior separate from permanent deletion while ensuring a full sync cannot resurrect an explicitly deleted ID.

- [ ] **Step 4: Wire configured intervals and foreground sync.**

Validate the user interval, re-register WorkManager when it changes, and trigger a non-blocking sync on app resume. Surface last success/failure in settings.

- [ ] **Step 5: Run sync, storage, and UI tests.**

```powershell
flutter test test/http_transport_test.dart test/sync_engine_test.dart test/sync_pairing_test.dart test/storage_recovery_test.dart
flutter analyze --no-pub
```

- [ ] **Step 6: Commit incremental sync.**

```powershell
git add lib/core/sync lib/core/models/task_list.dart lib/core/storage lib/core/settings lib/ui/pages/settings_page.dart lib/l10n test
git commit -m "feat(sync): 增加增量游标与删除墓碑"
```

### Task 8: Complete Windows runtime and release pipeline

**Files:**
- Modify: `pubspec.yaml`
- Modify: `installer/verb_task.iss`
- Modify: `windows/runner/main.cpp`
- Modify: `windows/runner/Runner.rc`
- Modify: `lib/app/windows_tray.dart`
- Modify: `lib/app/autostart.dart`
- Modify: `lib/app/window_control.dart`
- Modify: `lib/main.dart`
- Modify: `android/app/build.gradle.kts`
- Modify: `README.md`
- Modify: `docs/roadmap.md`
- Create: `CHANGELOG.md`
- Modify: `.github/workflows/verify.yml`

**Interfaces:**
- Product display name is `VerbTask`; executable, installer, Android label, notifications, and metadata use a documented consistent naming policy.
- Release version is derived from `pubspec.yaml`; installer version cannot drift.
- Release APK is signed by an injected release key; local builds without that key fail clearly instead of silently using debug signing.

- [ ] **Step 1: Add version/brand and artifact consistency checks.**

Check installer version, `pubspec.yaml`, executable metadata, Android label, release filenames, and changelog in a script/CI step. Make the current mismatch fail before build publication.

- [ ] **Step 2: Implement runtime fixes.**

Set the tray icon through the plugin using a packaged multi-size ICO, apply the default autostart policy during startup, remove hand-written quoting from the Run value, set a safe main-window minimum size, and verify relative paths always use application support data.

- [ ] **Step 3: Configure release signing without committing secrets.**

Read keystore properties from environment/ignored local files. A release build without required signing values must produce an explicit actionable error.

- [ ] **Step 4: Build and verify Windows/Android artifacts.**

```powershell
flutter analyze --no-pub
flutter test
flutter build windows --release
ISCC.exe installer\verb_task.iss
flutter build apk --release
apksigner verify --verbose build\app\outputs\flutter-apk\app-release.apk
```

Install in a clean Windows profile, test upgrade/uninstall/data retention, tray/quick-note/DPI/notification click, and record results. Verify the APK is not debug signed.

- [ ] **Step 5: Add release documentation and tag only after artifact checks.**

Update README, roadmap, testing reports, changelog, release notes, and SHA-256 files together. Create a version tag only after the exact commit passes all gates.

- [ ] **Step 6: Commit release engineering changes.**

```powershell
git add pubspec.yaml installer windows android README.md docs/roadmap.md CHANGELOG.md .github
git commit -m "chore(release): 建立可重复发布门禁"
```

### Task 9: Recurring-instance semantics and final acceptance

**Files:**
- Modify: `lib/core/models/task.dart`
- Modify: `lib/core/rrule/rrule_service.dart`
- Modify: `lib/core/notifications/reminder_service.dart`
- Modify: `lib/core/services/task_service.dart`
- Modify: `lib/core/sync/sync_engine.dart`
- Modify: `lib/ui/pages/task_edit_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Test: new recurrence, notification, sync, migration, and UI tests

**Interfaces:**
- A recurring series has a stable `seriesId`, occurrence key, exception set, and explicit edit scope: one occurrence, this-and-future, or whole series.
- Completing/skipping one occurrence does not complete the series.
- Notifications and sync carry occurrence identity and preserve exceptions.

- [ ] **Step 1: Write a design-level failing test matrix.**

Cover one-off edit, this-and-future edit, whole-series edit, one occurrence completion, skipped occurrence, `COUNT`, `UNTIL`, month-end, timezone/DST, sync conflict, and migration from old tasks without occurrence data.

- [ ] **Step 2: Implement the model and migration.**

Add the minimum serialized occurrence/exception fields, migrate existing tasks to an empty exception set, and keep old non-recurring tasks behavior unchanged.

- [ ] **Step 3: Implement UI confirmation and service operations.**

Every series edit must present the three scopes before mutation. The confirmation result must flow to one service method so UI and sync cannot diverge.

- [ ] **Step 4: Implement multi-instance notification scheduling and navigation.**

Expand a bounded future window, derive stable notification IDs, and carry occurrence identity in payload. Rebuild the window after every relevant mutation and recovery.

- [ ] **Step 5: Run final unit, widget, emulator, LAN, and Windows acceptance.**

Record commands, environment, screenshots/logs, and results in the test checklist. A release is complete only when every P0/P1 row has direct evidence and no test warning remains.

- [ ] **Step 6: Commit the recurrence feature and final documentation.**

```powershell
git add lib test docs README.md CHANGELOG.md
git commit -m "feat(recurrence): 支持系列与实例级操作"
```
