# WP-02 测试计划：三库三账号与跨服务契约

## 目标与验收范围

WP-02 对应验收项 `M05`（三库三账号隔离）和 `M20`（可恢复、可审计的基础设施）。目标是证明：

- 生产目标为同一 PostgreSQL cluster 中的 `new_api`、`opc_core`、`super_canvas` 三个独立 database；
- 三个服务分别使用 owner、migration、runtime 身份，运行时账号只拥有本服务所需权限；
- `super_canvas` 不拥有 New API 钱包、账本、充值、模型渠道等业务表的读写权限；
- 三库可以独立执行 migration、备份和恢复，不存在跨 database foreign key 或跨库 SQL 写入；
- 服务之间只通过 `contracts/platform-integration.openapi.yaml` 定义的 API/事件传递用户、任务、报价、预扣、结算等引用；
- migration 可重复执行（幂等），失败时可回滚或按文档恢复；
- 代码合并前必须有可复核的数据库权限导出、迁移日志和静态契约检查结果。

当前证据基线：`infra/postgres/opc_core/001_init.sql`、`infra/postgres/super_canvas/001_init.sql`、`infra/postgres/roles.sql`、`contracts/platform-integration.openapi.yaml`、`scripts/validate_contracts.py`。本文件不要求也不允许提交密码、DSN 中的密码、生产备份或供应商密钥。

## 前置条件与环境

执行数据库测试需要临时 PostgreSQL 15+ cluster（本地容器或专用测试实例均可），并设置以下仅存在于当前 shell 的 DSN：

```powershell
$env:ZSXQ_NEW_API_ADMIN_DSN  = "postgres://.../new_api"
$env:ZSXQ_OPC_CORE_DSN      = "postgres://.../opc_core"
$env:ZSXQ_SUPER_CANVAS_DSN  = "postgres://.../super_canvas"
```

DSN 必须分别使用测试 admin/migration/runtime 身份验证，不能复用生产凭据。测试完成后销毁临时 cluster 或清空测试数据库。

## 测试矩阵

### 1. 数据层测试

| 编号 | 检查 | 执行方式 | 通过标准 |
|---|---|---|---|
| D01 | 三库和角色存在 | 以 cluster admin 创建 `new_api`、`opc_core`、`super_canvas`，创建各库 owner、migration、runtime 角色；记录 `pg_database`、`pg_roles` 脱敏导出 | 三库名称唯一；业务服务不共享 runtime 角色；角色无明文密码入库；New API 的 owner/migration 由其服务管理 |
| D02 | schema 对象归属 | 分别执行 `\dt+`、`\dv`、`\df`、`\dx` 和 `information_schema` 查询，生成每库对象清单 | `opc_core` 仅含服务注册、事件、策略、审计索引；`super_canvas` 仅含用户引用、项目、任务、节点、素材引用、只读分享；画布不存在 `wallet`/`ledger`/充值表 |
| D03 | 跨库引用扫描 | 对全部 migration 做 `rg -n "(REFERENCES|JOIN|INSERT INTO|UPDATE|DELETE FROM).*\b(new_api|opc_core|super_canvas)\b"`，并查询 `pg_constraint` 外键定义 | 不存在跨 database foreign key、FDW、dblink 或跨库业务写入；跨服务 ID 只以 UUID/string 存储 |
| D04 | 约束和索引完整性 | 在每库执行 `\d+`、`pg_constraint`、`pg_indexes` 查询，插入最小合法/非法 fixture | owner、user、project、task 等本库外键和 check constraint 生效；`business_events.idempotency_key`、模型/任务快照相关唯一约束存在 |
| D05 | migration 幂等 | 在干净测试库执行每个 migration 两次或三次，记录 `psql` 输出和 `schema_migrations`/对象快照差异 | 重复执行退出码为 0；不重复创建对象、不重置数据、不产生重复索引；第二次执行前后 schema hash 一致 |
| D06 | 备份恢复可行 | 对三个库分别执行 `pg_dump --format=custom`、创建新库并 `pg_restore`，再运行对象/约束清单 | 三库可独立恢复；恢复顺序不依赖跨库外键；关键表行数、约束和索引与源库一致 |

### 2. 功能、权限与审计测试

| 编号 | 检查 | 执行方式 | 通过标准 |
|---|---|---|---|
| F01 | New API 钱包隔离 | 以 `super_canvas_runtime` 连接 `new_api`，尝试读取/写入钱包、账本、用户余额、充值订单和渠道表；以 `opc_core_runtime` 重复 | 连接或对象访问被 PostgreSQL 拒绝；画布没有余额写权限；合法路径只能调用内部报价/预扣/结算 API |
| F02 | 本服务最小权限 | 以各 runtime 账号执行本服务 CRUD：`opc_core` 事件接收/审计写入，`super_canvas` 项目/任务/素材写入；尝试 `CREATE TABLE`、`DROP`、`ALTER`、读取其他库 | 允许操作仅覆盖本服务表；DDL、其他服务表和其他 database 均拒绝；权限导出可解释每项 grant |
| F03 | migration 权限边界 | 以 migration 账号运行升级和回滚；以 runtime 账号重复执行 migration | migration 账号可完成迁移；runtime 账号不能执行 DDL 或修改 migration 元数据；迁移账号不用于应用运行时连接 |
| F04 | 事件幂等与审计 | 向 `opc_core.business_events` 使用相同 `Idempotency-Key` 提交两次，再提交同 key 不同 payload；检查 `cross_service_audit_events` | 首次写入成功；重复同 payload 返回同一业务结果；同 key 不同 payload 返回冲突；每次请求有 request/task/user 引用，敏感值不入日志 |
| F05 | 契约字段和错误语义 | 针对 SSO、catalog、quote、reserve、proxy invoke、settlement endpoint 发送最小合法、缺字段、非法 capability、重复幂等键请求 | 错误响应符合 4xx/409 约定；`price_version`、`reservation_id`、`task_id` 和能力标签在调用链中保持一致；禁止服务直接写钱包 |
| F06 | 权限撤销与回收 | 撤销 runtime role 的 CONNECT 或表权限，再使用旧连接/新连接测试；回收服务注册后重试事件 | 新连接立即拒绝；旧连接按连接池回收策略失效；撤销/禁用动作有审计记录且不删除账务事实 |

### 3. 模拟操作/数据流测试

| 编号 | 场景 | 操作 | 通过标准 |
|---|---|---|---|
| C01 | 画布创建任务 | `super_canvas` 创建 project/task，引用 New API `user_id`、`platform_model_id`、`price_version`、`reservation_id`；通过 contract 发送 quote/reserve 请求 | 画布只保存外部引用和快照，不查询或写入 New API 表；任务可通过 `task_id` 追踪到事件和审计记录 |
| C02 | 任务结算 | 模拟成功、失败、取消、审核拒绝四种 settlement outcome，并重复发送同一 idempotency key | 钱包变化只由 New API 结算端完成；画布收到结果后更新本地任务状态；重复请求不重复扣款或退款 |
| C03 | 迁移/恢复演练 | 在测试库写入最小 project/task/event 数据，分别 dump/restore 单库，再执行应用查询 | 单库恢复后本服务可启动；缺少其他库时服务以明确依赖错误失败，不通过跨库 SQL 绕过边界 |
| C04 | 服务异常和权限拒绝 | 关闭 `opc_core` 或撤销其 runtime 权限，提交画布任务和事件；恢复服务后重试 | 失败可重试且幂等；不会在画布本地扣款；请求、拒绝原因和补偿状态可审计 |

### 4. Smoke 与静态检查

| 编号 | 检查 | 命令/证据 | 通过标准 |
|---|---|---|---|
| S01 | 契约与数据库边界静态检查 | `python scripts/validate_contracts.py` | 输出 `WP-02 contract and database boundary checks passed`，且无跨库 FK、画布 wallet/ledger 或缺失 endpoint |
| S02 | SQL 语法检查 | 对每个迁移执行 `psql --set ON_ERROR_STOP=1 --file ... --single-transaction`（目标为临时测试库） | 所有 migration 退出码为 0；错误包含文件和行号；不在目标库外产生对象 |
| S03 | 权限快照检查 | `pg_dumpall --roles-only`、`\dp`、`\dn+`、`information_schema.role_table_grants` 脱敏保存 | 权限快照能证明 owner/migration/runtime 分离；禁止 grant、PUBLIC 权限和跨库角色继承均有结论 |
| S04 | 契约结构校验 | 使用固定版本 OpenAPI parser（如项目 CI 已采用的工具）解析 `contracts/platform-integration.openapi.yaml` | YAML 可解析；必需 path、schema、`Idempotency-Key` 和 `price_version` 存在；无未解析的 `$ref` |
| S05 | 变更质量检查 | `git diff --check`、`python scripts/validate_acceptance.py`、安全扫描工作流 | 无空白错误、验收矩阵结构有效、无凭据形态内容；PR 描述关联 `M05`/`M20` 和本测试报告 |

## 当前可执行性与阻断条件

截至 2026-09-22：

- **可执行**：`python scripts/validate_contracts.py` 已可在本地运行并通过；静态扫描可检查现有 migration 是否包含跨库引用；SQL 文件、OpenAPI 契约和验收矩阵均已存在。
- **暂不能执行**：当前开发机未发现 `psql`（`psql not found`），因此 D01-D06、F01-F06、C01-C04、S02-S04 无法产生 PostgreSQL 运行证据。
- **实现阻断**：`infra/postgres/roles.sql` 中 runtime grant 目前是注释示例，不是可执行的权限迁移；尚未形成三库 owner/migration/runtime 账号创建和授权的可重复脚本。没有这部分，不能声称 F02/F03 或 M05 通过。
- **运行阻断**：`new_api` 的实际 schema/migration 由上游 New API 管理，当前 WP-02 目录没有其迁移副本或目标版本清单；必须提供固定版本、迁移入口和只读权限证据后，才能完成 D02/D06。
- **安全阻断**：未创建隔离测试 cluster、临时角色和脱敏权限快照前，不得连接生产 PostgreSQL；不得用真实支付/用户数据验证。

阻断解除条件：补齐可重复执行的三库/角色/授权迁移；提供 PostgreSQL 15+ 测试实例和 `psql`；固定 New API schema 版本；执行并保存 D01-D06、F01-F06、C01-C04、S02-S04 的脱敏证据。

## 结果状态与合并标准

每个测试记录命令、环境版本、数据库名称（不含密码）、结果、证据路径和失败重现。状态只能为 `planned`、`in_progress`、`passed` 或 `blocked`：

- `passed`：所有 P0 项（D01-D05、F01-F05、S01-S04）有运行证据，M05/M20 的证据链完整，无 P0/P1 缺陷；
- `blocked`：缺 PostgreSQL、权限脚本、New API schema 基线或任何跨库写入/越权风险未处置；
- `in_progress`：静态检查通过但运行证据尚未完整；
- `planned`：尚未开始执行。

WP-02 PR 合并前必须：

1. 关联 `M05`、`M20`，附本计划对应的执行报告和脱敏权限/迁移证据；
2. `Acceptance Gate / acceptance`、`Security Gate / secret-scan` 通过；
3. `scripts/validate_contracts.py`、migration 幂等、最小权限和跨库拒绝测试均通过；
4. 明确回滚：撤销本次角色授权、恢复三库备份、按库回退迁移；
5. 不得以“静态 SQL 扫描通过”替代真实权限拒绝、迁移重复执行和备份恢复证据。

## 证据记录模板

```text
验收编号：M05 / M20
工作包：WP-02
数据库/角色：仅记录脱敏名称
执行环境：PostgreSQL、psql、操作系统版本
前置数据：最小 fixture / 空库 / 备份文件哈希
命令：
预期结果：
实际结果：
证据路径：
失败重现：
状态：planned / in_progress / passed / blocked
执行人：
复核人：
日期：
```
