# 个人任务管理 App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 Flutter 构建一个个人自用 + 开源(MIT)的 Android+Windows 任务管理 App：纯本地 SQLite 数据、局域网同步、中英双语、本地通知提醒、三级自然语言录入（离线中文→LLM→手动）。

**Architecture:** Flutter 单代码库；业务层（任务/清单/回收站 CRUD、RRULE、提醒、NLP、同步）与 UI 分离；SQLite 本地存储；同步采用「Windows=Server 常驻 + Android=Client 发起」的局域网增量同步（oplog + version 冲突合并）。

**Tech Stack:** Flutter；SQLite（`drift`）；Riverpod（状态）；`flutter_local_notifications`（提醒）；`tray_manager`/`window_manager`（Windows 托盘）；mDNS（`bonsoir`/`multicast_dns`）；WorkManager（Android 后台同步）；`rrule`（Dart 包）展开重复任务；本地中文 NLP 规则解析器 + 可选 OpenAI 兼容 LLM client；`flutter_localizations`（中英双语）。

**Spec:** `docs/方案设计.md`、`docs/项目调研报告.md`

## Global Constraints

- 平台最低：Android 8+（API 26）、Windows 10 x64。
- 存储一律 UTC；`dateOnly` 任务展示不随夏令时偏移。
- 数据模型不得丢失 `version`/`updatedAt`/`changeId`（冲突判定与同步去重依赖）。
- 所有写入（除同步合并外）必须同时写 oplog(outbox)。
- NLP 解析结果必须经用户确认后才落库。
- 词条、界面文案走 `l10n`（中/英），不得硬编码中文到英文分支。
- 核心逻辑（RRULE 展开、NLP、同步合并、oplog）必须单测，TDD 优先。
- 许可 MIT，仓库根放 `LICENSE`。

---

## Task 1: 项目脚手架与多平台配置

**Files:**
- Create: `pubspec.yaml`、`lib/main.dart`、`lib/app.dart`、`android/`、`windows/`
- Test: `test/widget_smoke_test.dart`

**Interfaces:**
- Produces: `App`（MaterialApp 根组件，含 i18n 文案），供 UI 任务使用。

- [ ] **Step 1**: `flutter create . --platforms=android,windows`，在 `pubspec.yaml` 加依赖（drift、riverpod、flutter_local_notifications、rrule、bonsoir、tray_manager、window_manager、flutter_localizations、intl）。
- [ ] **Step 2**: 写冒烟测试 `test/widget_smoke_test.dart`：build `App`，断言出现应用标题。
- [ ] **Step 3**: 跑 `flutter test`，确认 FAIL（`App` 未定义）。
- [ ] **Step 4**: 实现 `lib/app.dart` 的 `App`（MaterialApp + l10n Delegates + 空首页）。
- [ ] **Step 5**: 跑 `flutter test` 通过；`git commit`

## Task 2: 数据模型与 SQLite 存储层

**Files:**
- Create: `lib/core/models/task.dart`、`list_model.dart`、`reminder.dart`
- Create: `lib/core/storage/database.dart`（drift tables）、`app_database.dart`

**Interfaces:**
- Produces: `AppDatabase`（drift，表：Task/List/Reminder/Oplog）；`Task`/`TaskList`/`Reminder` 类含 `version`、`updatedAt`、`changeId`。

- [ ] **Step 1**: 写失败测试：可 `insert`/`query` 一个 Task，含必填字段。
- [ ] **Step 2**: 定义 drift 表与实体类（字段见方案 §5 + §12.2）。
- [ ] **Step 3**: 实现存储层；跑测试通过。

## Task 3: 任务/清单/收件箱 CRUD + 回收站

**Files:**
- Create: `lib/core/services/task_service.dart`
- Test: `test/task_service_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`
- Produces: `TaskService`：`create/edit/complete/recycle/restore/deletePermanent/query`；每次写库同时写 oplog。

- [ ] **Step 1**: 写失败测试：创建→编辑→完成→移入回收站→恢复→彻底删除，并验证 oplog 条目数一致。
- [ ] **Step 2**: 实现 `TaskService`。
- [ ] **Step 3**: 测试通过。

## Task 4: 周期性任务（RRULE）

**Files:**
- Create: `lib/core/rrule/rrule_service.dart`
- Test: `test/rrule_service_test.dart`

**Interfaces:**
- Consumes: Dart `rrule` 包；`Task`（含 rrule, due, status）
- Produces: `nextDue(task, now)`（返回下一个未完成实例）；`instances(task, from, to)`。

- [ ] **Step 1**: 写失败测试：日/周/月/每工作日/每月第 N 日/每隔 N 周 的 `nextDue`。
- [ ] **Step 2**: 实现（封装 rrule 展开 + 前进到未完成实例）。
- [ ] **Step 3**: 测试通过。

## Task 5: 提醒调度

**Files:**
- Create: `lib/core/notifications/reminder_scheduler.dart`
- Test: `test/reminder_scheduler_test.dart`

**Interfaces:**
- Consumes: `TaskService`、`rrule_service`、`flutter_local_notifications`
- Produces: `schedule(task)`、`cancel(task)`；按"下一个未完成实例 + 全局/单条提前量"排本地通知；`clearOnComplete`。

- [ ] **Step 1**: 失败测试：给指定到期任务排提醒，位置正确；完成实例后取消。
- [ ] **Step 2**: 实现排程（`zonedSchedule`）；Android 申请通知/精确闹钟权限。
- [ ] **Step 3**: 通过。

## Task 6: 自然语言录入（离线中文）

**Files:**
- Create: `lib/core/nlp/zh_parser.dart`、`nlp_service.dart`
- Test: `test/nlp_test.dart`

**Interfaces:**
- Produces: `parseZh(text) -> NlpResult{ title?, due?, rrule?, needsConfirm }`；`NlpService.parse(text) -> ParsedDraft`（低置信度置 `needsConfirm=true`）。

- [ ] **Step 1**: 失败测试：`下周三下午3点交报告`、`明天`、`每天晚上9点锻炼` 等中文样例，解析出标题/日期/重复，且必然 `needsConfirm=true`。
- [ ] **Step 2**: 实现中文规则解析器（词典+正则+节假日表骨架）。
- [ ] **Step 3**: 通过。

## Task 7: 可选 LLM 增强解析

**Files:**
- Create: `lib/core/nlp/llm_client.dart`
- Test: `test/llm_client_test.dart`

**Interfaces:**
- Consumes: 用户设置里的 `baseUrl`+`apiKey`（存本地）；`NlpResult` schema
- Produces: `enhance(text) -> NlpResult`；默认关闭；开启前 UI 显示"数据将发送到该服务"。

- [ ] **Step 1**: 失败测试：mock HTTP 返回 JSON 映射为 `NlpResult`；未配置时抛"未启用"。
- [ ] **Step 2**: 实现 OpenAI 兼容 `/responses|/chat/completions` 客户端。
- [ ] **Step 3**: 通过。

## Task 8: 局域网同步引擎（Server/Client + oplog + 冲突合并）

**Files:**
- Create: `lib/core/sync/sync_server.dart`、`sync_client.dart`、`oplog.dart`、`conflict_resolver.dart`
- Test: `test/sync_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`(oplog)、mDNS、`QRCode`（配对）
- Produces: `SyncServer`(Windows)：mDNS 广播、接收增量、返回追平；`SyncClient`(Android)：握手→增量拉取/推送→按 `(version,updatedAt)` 合并；删除经 oplog 传播。

- [ ] **Step 1**: 失败测试：双向增量同步后两端一致；重复 changeId 不重复应用；冲突按更高 version 胜出。
- [ ] **Step 2**: 实现 oplog 去重 + 冲突 resolver（LWW by version） + 传输。
- [ ] **Step 3**: 通过；联调 mDNS 发现与扫码配对。

## Task 9: 同步触发与 Windows 托盘

**Files:**
- Create: `lib/app/windows_tray.dart`、`lib/core/sync/sync_trigger.dart`
- Test: `test/sync_trigger_test.dart`

**Interfaces:**
- Consumes: `SyncClient`、`tray_manager`、`WorkManager`
- Produces: `SyncTrigger`：按可配置频率（默认较长）+ 手机回前台 + 手动"快速同步"触发；Windows 托盘菜单（显示/退出）；开机自启默认开、可关。

- [ ] **Step 1**: 测试：手动触发→调用 SyncClient；频率配置生效。
- [ ] **Step 2**: 实现触发逻辑 + 托盘 + 自启设置。
- [ ] **Step 3**: 通过。

## Task 10: UI（收件箱 / 清单 / 看板 / 编辑 / 搜索 / 设置）+ 双语

**Files:**
- Create: `lib/ui/*`（inbox.dart、lists.dart、board.dart、task_edit.dart、search.dart、settings.dart）
- Test: `test/ui_*.dart`

**Interfaces:**
- Consumes: 各 service；`l10n`
- Produces: 可交互 UI；NLP 弹窗确认流；一键中英切换。

- [ ] **Step 1**: 收件箱与清单列表页（CRUD 接线）。
- [ ] **Step 2**: 看板按状态（未开始/进行中/完成）。
- [ ] **Step 3**: 任务编辑（含备注、两种截止日期、重复、提醒、优先级弱化+按截止排序）。
- [ ] **Step 4**: 搜索/排序/筛选；NLP 录入弹窗确认。
- [ ] **Step 5**: 设置（双语切换、同步频率、LLM 配置、备份/导出/导入、托盘/自启开关）。
- [ ] **Step 6**: 冒烟测试。

## Task 11: 导入导出与打包发布

**Files:**
- Create: `lib/core/storage/backup_service.dart`
- Test: `test/backup_test.dart`

- [ ] **Step 1**: 测试：导出 JSON/CSV→重新导入→数据一致。
- [ ] **Step 2**: 实现导出/导入。
- [ ] **Step 3**: Android 签名 APK、Windows（Inno Setup/MSIX）安装包构建脚本；`README` 安装说明；`LICENSE`(MIT)。
