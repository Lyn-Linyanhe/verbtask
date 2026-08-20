# VerbTask v0.3 可靠局域网同步 —— 设计

> 状态：2026-08-20 评审版
> 依据：`docs/方案设计.md`、`docs/roadmap.md`、`docs/项目调研报告.md`、当前同步原型代码核验

## 1. 目标与范围

让 Android 与 Windows 在同一局域网内稳定、安全、可恢复地同步任务与清单。当前原型是「无认证 + 全量快照」，只能演示握手；v0.3 把它升级为「配对外发确认 + 增量、幂等、可断点续传 + 删除墓碑 + 清单同步」。

范围（本版完成）：
1. 配对认证：共享令牌，Server 校验，Client 携带。
2. 增量任务同步 + 同步游标（watermark）+ changeId 幂等去重。
3. 删除传播：回收站（软删除）通过删除墓碑同步；彻底删除仅本机。
4. 清单同步：低基数实体用快照段同步（LWW）。

明确不做（记录到 v0.4 / 后续）：
- 字段级 CRDT（Yrs/Automerge）——保留任务级 LWW，简单可预期。
- 重复任务实例状态机迁移——单列（需实例化模型），列入 v0.3 后续或 v0.4。
- 云端/WebDAV/CalDAV 后端——LAN 不变，扩展点在同步抽象之上。

## 2. 拓扑与角色

- Windows = Server：常驻 `SyncHost`，监听 HTTP，提供增量 `/pull` 与 `/push`，并应答局域网发现。
- Android = Client：打开 App、回前台或手动「快速同步」时发现 Server 并执行一次双向同步。
- 无中心服务器、无账号；同一局域网内配对后即可同步。

## 3. 配对认证

- Windows 端生成/展示一个短期配对码（如 6 位数字），并存储一个持久 `syncToken`（随机 64 hex）。
- Android 端输入配对码，双方从「共享秘密」派生同一 `syncToken`（HMAC-SHA256(serverId, code) 之类的确定性派生），或更简单：Windows 直接把 `syncToken` 显示为配对码，Android 输入后本地保存。
- 每个请求携带 `Authorization: Bearer <syncToken>`；Server 缺失或错误时返回 401，不泄露数据。
- 设计选择：本版用「直接输入/显示 token」作为配对；扫码/带外交换是后续增强。

## 4. 增量同步协议（任务）

- Repository 已有 `Change{changeId, taskId, kind, timestamp, version}` 与 `changesSince(cursor)`（oplog）。`changeId` 全局唯一（UUID），是幂等与断点续传的锚点。
- GET `/pull?after=<cursor>&token=..`：
  - 返回 `{ changes: [ {changeId, taskId, kind, version, deleted, task:{...}} ], cursor, lists:[...] , listsVersion }`。
  - `changes` = `changesSince(after)` 逐条，每条附带该任务在该 change 之后的最新快照（便于直接落库）。
  - `cursor` = 最后一条已发送变更的 changeId（无变更时等于 `after`）。
  - `lists`：全量清单快照（低基数）。
- POST `/push` `{ changes:[...], token }`：
  - 幂等：对每个 change，若 `changeId` 已存在于本地 oplog 则跳过，否则应用（upsert task / delete tombstone）。
  - 返回 `{ applied:[...changeId], cursor }`。
- Client 侧 `SyncEngine.mergeRemote` 语义升级：
  - 以 changeId 去重（`seenChangeIds`）。
  - 单任务内部按 `(version, updatedAt, changeId)` LWW 合并。
  - 本地未在远端（`toPush`）= 本地比远端新增/更新的变更，写回 Server。
  - 删除：`deleted:true` 作为一个 upsert 后的墓碑（与普通任务同构），统一走 change 流。

## 5. 游标与断点续传

- Client 在本地持久化 `syncCursor`（最近应用的远端 changeId）。
- 下次同步用该 cursor 作 `after`，Server 只返回其后变更 → 增量 + 断点续传 + 幂等。
- 冲突基准仍是 `(version, updatedAt, changeId)`，version 为单调逻辑计数器（Lamport 式）；墙钟 `updatedAt` 仅作展示与同版本排序。

## 6. 清单同步

- 清单数量少、变更频率低，采用每条同步消息内的快照段 `lists:[...]`。
- Server 与 Client 各自本地集的 LWW：合并基准用 TaskList 的 `updatedAt`（保留 version/change 演进空间，v0.3 用 updatedAt 即可）。
- 删除清单：软删除清单不需物理删除对象（见 §7），因此快照段天然收敛。

## 7. 删除语义（墓碑）

- 回收站：`Task.deleted=true`（软删除）→ 作为普通 change 传播；另一端把任务标记为已删除（在其本地「已删除」视图/回收站可见或隐藏由本地策略决定）。
- 恢复：在发起端恢复并生成新 change 传播。
- 彻底删除（物理，`deletePermanent`）：仅本机，不同步；因此另一端若已有该任务则可能留下「孤立」记录——本版接受该语义并在文档注明（因为回收站只在发起端存在）。

## 8. 触发策略（沿用 v0.2 既定，不动摇）

- Windows：常驻 → Server 持续可同步。
- Android：打开 App / 回前台 / 手动「快速同步」/ WorkManager 周期后台（默认 30 分钟，可调）。
- 后台同步成功后再全量重排提醒（沿用 `AppNotifications.rescheduleAll`）。

## 9. 数据模型 / 兼容

- 复用现有 `Task` / `TaskList` / `Change` 序列化；新增字段必须带默认值。
- 新增设置键：`syncToken`（持久化）。旧数据无 token 时，Server 生成并展示一次；Android 输入后本地保存。
- 不改变版本号格式；格式仍是 `{version:1, tasks, lists, changes}`。

## 10. 验收标准

- 无 token / 错 token 请求被 Server 401 拒绝，正确 token 可拉取/推送。
- 两个实例经增量同步收敛：先只传新增 change，再做 idempotent re-push 无副作用；断点续传（掉线后带 cursor 重连）补齐剩余增量。
- 删除（回收站）在另一端反映；恢复亦同步。
- 清单增删改在两实例间收敛。
- `flutter analyze`、全量测试、Android debug 与 Windows 构建通过；模拟器冒烟（配对 + 两端同步）通过。

## 11. 决策记录（ADR v0.3）

- ADR-101：配对用「直接展示/输入 syncToken」而非扫码（扫码列为增强）。
- ADR-102：任务同步用 oplog 增量 + changeId 幂等 + LWW，不用 CRDT（与 v0.2 ADR-003 一致）。
- ADR-103：清单用快照段（低基数）而非 oplog；文档注明若清单量增长改增量。
- ADR-104：彻底删除不同步；回收站仅发起端本地（与 v0.2 方案自审 S4 一致）。
