# WP-01 数据库架构草案

状态：设计与离线脚本，未部署、未迁移。所有建库和角色变更均须单独获得基础设施负责人确认；本文不授权对现有数据库执行脚本。

## 边界和归属

```text
                    New API 受控服务接口 / 一次性 SSO
                                  |
             +--------------------+--------------------+
             |                    |                    |
       +-----v------+       +-----v------+       +-----v--------+
       |  new_api   |       |  opc_core  |       | super_canvas |
       | New API    |       | OPC 服务   |       | TapCanvas    |
       | 身份、目录、 |       | 会话、流程、 |       | 项目、任务、  |
       | 余额、账务   |       | 运行、素材   |       | 节点、资产    |
       +------------+       +------------+       +--------------+
          独立连接池、独立登录角色、独立迁移版本和备份/恢复边界
```

New API 是用户 ID、模型可用性、授权、余额和结算的权威来源。OPC 与 TapCanvas 仅保存 `new_api_user_id bigint`、授权的 `key_id`、模型/价格快照及预扣 ID 等最少引用，通过受控 API 校验状态；不保存用户上游 API Key，不直接读写 New API 钱包或渠道表。跨库业务引用不建外键、不跨库 JOIN；服务 API、幂等键、事件对账和失效补偿承担一致性。两个子项目各自的本库外键可以使用。New API 用户主键为整数；现有 `opc_core.cross_service_audit_events.user_id uuid` 不得冒充 New API 用户 ID，后续新增 `new_api_user_id bigint` 后才可关联审计记录。

## 角色与权限矩阵

每库有三个专属角色；九个角色互不交叉授权，且不授予 `SUPERUSER`、`CREATEDB`、`CREATEROLE` 或 `BYPASSRLS`。集群管理员仅执行一次受控引导，不用于应用连接。登录密码由密钥管理器注入，脚本中的 `CHANGEME` 只用于离线模板。

| 数据库 | owner（NOLOGIN） | migration（LOGIN, NOINHERIT） | runtime（LOGIN） |
| --- | --- | --- | --- |
| `new_api` | `zsxq_new_api_owner`，拥有数据库、schema 和对象，无应用连接 | `zsxq_new_api_migration`，仅本库 `CONNECT`，经 `SET ROLE` 获取本库 DDL；批准的 schema 变更 | `zsxq_new_api_runtime`，本库 `CONNECT`、schema `USAGE` 和业务表 DML/序列使用；New API 请求 |
| `opc_core` | `zsxq_opc_core_owner`，同上 | `zsxq_opc_core_migration`，同上；OPC 迁移 | `zsxq_opc_core_runtime`，同上；OPC 服务 |
| `super_canvas` | `zsxq_super_canvas_owner`，同上 | `zsxq_super_canvas_migration`，同上；画布迁移 | `zsxq_super_canvas_runtime`，同上；画布服务 |

建库脚本为 [`db/init/00-create-databases.sql`](../../../db/init/00-create-databases.sql)，仅适用于**空集群**。它撤销数据库和 `public` schema 的 PUBLIC 权限，owner 不登录，迁移登录只能 `SET ROLE` 到自己的 owner，runtime 无 DDL/跨库 `CONNECT`。对象必须由 owner 身份创建，默认权限才会给未来表授权；已有表仍需按库审核后单独 `GRANT`。连接池须使用各自 runtime 凭据，不复用管理员或 migration 凭据；禁止应用 `SET ROLE`。若需严格表级隔离，可进一步收紧上述库内 DML 授权。

当前 [`infra/postgres/roles.sql`](../../../infra/postgres/roles.sql) 使用同名 NOLOGIN 组角色，并已有两库的 schema/grant 基线。因此不能在当前环境直接重放空集群脚本，需先评审角色转换、对象所有权、现有数据和权限差异。New API 上游 [`vendor/new-api/model/main.go`](../../../vendor/new-api/model/main.go) 启动时执行 GORM `AutoMigrate`；在抽离启动 DDL、确认迁移账号可单独执行之前，严格 runtime 权限**不能直接投入现有 New API 启动流程**。

## 迁移目录与执行约定

```text
db/
  init/00-create-databases.sql
  migrations/
    new_api/README.md
    opc_core/README.md
    super_canvas/README.md
  scripts/check-cross-db-fk.sql
```

各目录独立维护 `000001_description.up.sql` / `000001_description.down.sql`，与 golang-migrate 的文件命名和版本表机制兼容。每次只给工具一个数据库 DSN 和一个目录；迁移 runner 必须保证创建版本表和执行每个迁移的连接均已 `SET ROLE` 为对应 owner，并用权限探针验证此约束，不能假定一次 `SET ROLE` 会自动覆盖连接池中的其他会话。不得在同一迁移里切换数据库、使用 FDW/dblink、更新另一个库，或用业务运行账号做 DDL。DDL 默认事务化；`CREATE INDEX CONCURRENTLY` 等不能在事务中的语句须独立迁移并记录重试策略。生产前以匿名化副本演练 `up`、`down`、再次 `up` 和恢复，记录耗时、锁影响及回滚点。

本次目录只建立迁移槽位，不填入会与已存在 `infra/postgres/*/001_init.sql` 或 New API GORM 表重复的初始迁移。正式 `000001` 前先冻结真实库版本、基线校验和所有权；存量环境可用版本标记纳管，但不得把未执行的 DDL 假报为已执行。

## 初始表与索引设计

以下是目标逻辑模型和迁移审查清单，非已执行 DDL。所有业务写入使用 `timestamptz`，敏感引用采用最小化存储；UUID 可由数据库或应用生成。本库 FK 应加索引，状态/时间组合索引按实际查询计划调整。

| 库 | 核心表与关键列 | 约束及索引 |
| --- | --- | --- |
| `new_api` | 上游 `users`（Go 模型 `User.Id int`）、`tokens`（用户/key）、`channels` / `models`（受控模型目录）、`logs`（用量）及现有账务表 | 保留上游实际 schema 与迁移所有权；用户主键、Token 唯一索引、日志用户/时间索引和结算幂等键索引须对照 GORM 模型与执行计划核实；集成新增的 scope、价格版本、预扣/退款表必须先由 New API 负责人批准，不在此处猜造上游 DDL |
| `opc_core` | 现有 `service_registrations`、`business_events`、`policy_versions`、`cross_service_audit_events`；计划新增 `opc_sessions(id, new_api_user_id, expires_at, revoked_at)`、`opc_workflows(id, new_api_user_id, version)`、`opc_runs(id, workflow_id, new_api_user_id, price_version, reservation_id, status)`、`opc_run_steps(id, run_id, step_key, status, actual_usage)`、`opc_assets(id, new_api_user_id, object_key, retention_until)`、`opc_prompt_assets`、`opc_audit_events` | 现有 `business_events(idempotency_key)`、`policy_versions(policy_type, version)` 唯一；新增 `opc_sessions(new_api_user_id, expires_at)`、`opc_workflows(new_api_user_id, updated_at)`、`opc_runs(new_api_user_id, status, created_at)`、`opc_run_steps(run_id, step_key)` 唯一、`opc_assets(new_api_user_id, retention_until)`、审计 `(new_api_user_id, created_at)`；`run_id`/`workflow_id` 本库 FK；`new_api_user_id` 无跨库 FK |
| `super_canvas` | 现有 `platform_user_refs`、`canvas_projects`、`canvas_tasks`、`canvas_task_nodes`、`asset_refs`、`readonly_shares` | 现有 `canvas_tasks(owner_user_id, status, created_at)`、`asset_refs(owner_user_id, retention_until)`、`canvas_task_nodes(task_id, node_key)` 唯一、`asset_refs(provider, object_key)` 唯一；`project_id`/`task_id` 为本库 FK；计划将现有 UUID `platform_user_refs.user_id` 与 New API `bigint` 身份对齐前，不得宣称该引用已绑定 New API 用户；需保留历史映射和兼容迁移 |

OPC 所有用户归属表使用 `new_api_user_id bigint NOT NULL`，在接口边界验证上游整数 ID 的取值范围。画布现有 `platform_user_refs.user_id uuid` 与 New API 整数 ID 不同，后续需先设计双读/映射和回填验证，不能直接改型导致孤儿记录。服务层所有查询和 worker 消费还必须从会话主体施加用户过滤；索引或本库外键不能替代授权检查。任务创建时固定 `price_version` 和模型快照；各节点记录预扣、实耗、失败/取消/审核拒绝退款的幂等事件，最终账务仍由 New API 结算。

## 跨库引用与审计门禁

[`db/scripts/check-cross-db-fk.sql`](../../../db/scripts/check-cross-db-fk.sql) 应分别连接三库执行。PostgreSQL 原生外键不能跨数据库，因此目录中不会存在真正的跨库 FK；脚本检查目录可见的外键端点是否涉及 foreign table，并拒绝指向另外两个业务库的 FDW server。它无法通过系统目录识别尚未执行的迁移 SQL、应用层 dblink 或任意业务字段语义，故代码审查仍需检查 `REFERENCES`、FDW/dblink、跨库 DSN 和数据访问路径。脚本在发现违规时 `RAISE EXCEPTION`，配合 `ON_ERROR_STOP=1` 返回非零。

审计记录应含 tenant/用户主体、请求与任务关联 ID、动作、结果、时间、策略/价格版本和最少必要的非敏感摘要；不得记录密码、完整 Cookie、长期令牌、原始 API Key、提示词/媒体正文或完整 SSO 授权码。账务与审计事件要有唯一幂等键、不可由 runtime 删除的保留策略及定期对账；若要强制不可删审计，需另行收紧审计表权限。按库制定加密备份、保留期、恢复演练、访问日志和删除/媒体清理策略。发布前要求独立权限审查、迁移/回滚审查、备份恢复证据和人工批准。

## 离线验收与未完成项

验收需在批准的隔离 PostgreSQL 环境用 `psql -X -v ON_ERROR_STOP=1` 验证建库脚本和三库检查脚本，并用权限探针证明 runtime 可读写本库授权表、不能建表、不能连接其他库；此处未做数据库实跑。迁移目录已建立，但具体迁移需待存量基线和上游 New API schema 冻结。完成这些前不得将本设计标记为生产可用。
