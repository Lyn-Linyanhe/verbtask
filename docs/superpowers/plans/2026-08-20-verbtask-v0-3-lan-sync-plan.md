# VerbTask v0.3 可靠局域网同步 —— 实施计划

> **For agentic workers:** 使用 TDD 逐任务实现；每任务先写失败测试 → 最小实现 → 聚焦测试 → 全量测试与分析。

**Goal:** 把当前「无认证 + 全量快照」的 LAN 同步原型升级为「配对认证 + 增量幂等 + 游标续传 + 删除墓碑 + 清单同步」。

**Spec:** `docs/superpowers/specs/2026-08-20-verbtask-v0-3-lan-sync-design.md`

## Global Constraints

- 复用现有 `Task`/`TaskList`/`Change` 序列化与 `changesSince`；新增字段必须有默认值。
- 冲突仍用任务级 `(version, updatedAt, changeId)` LWW；不引入 CRDT。
- 彻底删除（物理）不同步；回收站（软删除 `deleted:true`）走 change 流。
- 请求必须携带 `syncToken`；Server 缺失/错误返回 401。
- 后台同步成功后再全量重排提醒（沿用 v0.2）。
- 每个任务：先写失败测试，再最小实现；完成后跑聚焦 + 全量测试 + analyze。

---

### Task V1: 配对令牌（syncToken）与鉴权

**Files:** `lib/core/settings/local_settings.dart`、`lib/core/sync/http_transport.dart`、`lib/core/sync/sync_host.dart`

- [ ] **Step 1: 写失败测试**
  - 在 `test/http_transport_test.dart` 加：无 token / 错 token 的 `/pull`、`/push` 返回 401（不写数据）；正确 token 正常。
- [ ] **Step 2: 跑测试确认失败**（无鉴权 → 失败）
- [ ] **Step 3: 实现**
  - `LocalSettings.syncToken`（随机生成，一次）。
  - `SyncServer` 校验 `Authorization: Bearer <token>`；缺失/错误 → 401。
  - `SyncClient` 构造携带 token，请求加 header。
- [ ] **Step 4: 聚焦 + 全量测试 + analyze**

---

### Task V2: 增量任务同步 + 游标 + 幂等 + 删除墓碑

**Files:** `lib/core/sync/http_transport.dart`、`lib/core/sync/sync_engine.dart`、`test/http_transport_test.dart`、`test/sync_engine_test.dart`

- [ ] **Step 1: 写失败测试**
  - `/pull?after=<cursor>` 返回 `{changes, cursor, lists}`；无 after 返回全量。
  - 两次 push 相同 changes（re-idempotent）无副作用。
  - 断点续传：掉线后带 cursor 只补增量。
  - 删除（deleted:true）作为 change 在另一端体现。
- [ ] **Step 2: 跑测试确认失败**
- [ ] **Step 3: 实现**
  - Server `/pull` 用 `changesSince(after)`；每条 change 附带该任务最新快照；算 cursor。
  - Server `/push` 按 changeId 幂等应用（includes 检查）。
  - `SyncEngine.mergeRemote` 增加增量/去重语义，并返回用于续传的 cursor。
- [ ] **Step 4: 聚焦 + 全量测试 + analyze**

---

### Task V3: 清单快照同步

**Files:** `lib/core/sync/http_transport.dart`、`test/http_transport_test.dart`

- [ ] **Step 1: 写失败测试** — `/pull` 返回 lists 快照；Client merge 后两实例清单收敛；push 携带本地 lists。
- [ ] **Step 2: 实现** — pull/push 往返 `lists:[...]`，按 updatedAt LWW 合并。
- [ ] **Step 3: 聚焦 + 全量测试 + analyze**

---

### Task V4: 接线与冒烟

**Files:** `lib/main.dart`、`lib/core/sync/sync_controller.dart`、`lib/ui/pages/settings_page.dart`、`lib/l10n/*`、`lib/core/sync/background_sync.dart`

- [ ] **Step 1:** Settings 显示 Windows 端 syncToken、Android 端输入保存；HomePage/quickSync/backgroundSync 传 token。
- [ ] **Step 2:** 补 ARB 文案。
- [ ] **Step 3:** 模拟器冒烟：两台实例配对 → 增量收敛 → 删除同步 → 断点重连。
- [ ] **Step 4:** 最终验证矩阵：`flutter gen-l10n`、`dart format`、`flutter analyze`、`flutter test`、`flutter build apk --debug`、`flutter build windows`、`git diff --check`。
