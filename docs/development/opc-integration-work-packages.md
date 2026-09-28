# New API 接入 OPC 开发工作包

## 1. 目的、边界与当前事实

本文件将“New API 导航入口 + OPC（Agency Orchestrator）”拆分为可单独开发、验收和回滚的工作包。它是实施文档，不代表任何包已经完成或可上线。

已确认的产品决策：

- OPC 部署在独立子域名 `opc.<主域名>`，从 New API 顶栏同窗口进入。
- 只有 New API 中状态正常且已登录的用户可以使用；后台关闭 OPC 时，入口、SSO 和执行接口均拒绝访问。
- New API 是唯一账号、模型、用户余额、预扣、结算、退款和审计来源；用户不能在 OPC 填写 Provider Key、API Key 或第三方中转地址。
- 保留截图中未打叉的工作台、专家库、创意库、提示生成、运行记录、创意出片、角色团队、工作流模板和模型选择；红叉项不得导入、隐藏后保留，或通过 URL/API 间接暴露。

当前仓库已有 `vendor/new-api`、画布方向的内部契约草案及 `opc_core` 数据库基线。它们不能证明 OPC 已完成：契约中的 `/internal/v1/*` 尚未成为 New API 可用的生产接口，`opc_core` 也没有 OPC 会话、工作流、运行和素材表。

## 2. 总体顺序

```text
OPC-00 版本、许可证和运行边界冻结
  -> OPC-01 New API 顶栏入口与后台开关（默认关闭）
  -> OPC-02 独立子域名、反向代理和受控服务骨架
  -> OPC-03 New API 一次性 SSO 与 OPC 会话
  -> OPC-04 opc_core 用户隔离数据模型
  -> OPC-05 New API 模型目录与用户可用模型过滤
  -> OPC-06 New API 受控调用、预扣/结算/退款
  -> OPC-07 AO 页面派生与危险能力剥离
  -> OPC-08 工作流运行、任务状态与审计关联
  -> OPC-09 专家库、创意库、提示生成和出片素材
  -> OPC-10 安全、隔离和端到端验收
  -> OPC-11 灰度部署、观测、备份和回滚
```

`OPC-01` 可以先合并并保持关闭；不得在 `OPC-03`、`OPC-06` 和 `OPC-10` 完成前向真实用户开放。工作包只允许按上述顺序启动，`OPC-09` 可在 `OPC-08` 完成后与 `OPC-10` 的非阻断测试并行。

## 3. 工作包

### OPC-00 源码、许可证与运行边界冻结

**目标**：形成后续开发唯一可复核的输入，避免基于漂移上游或不明确许可实施。

**输入**：`vendor/new-api` 当前实际提交、`1240052492/agency-orchestrator` 提交 `0b41c9895b5ef1b70938999f2ada1b3637583574`、现有 New API 许可证审计。

**实现与交付物**：

- 固定 New API、AO 和 AO 角色/模板依赖的完整 commit、来源、构建命令和哈希；AO 进入独立私有派生仓，保留其 Apache-2.0 `LICENSE`、NOTICE 和上游同步记录。
- 生成两套依赖 SBOM；针对 New API AGPL-3.0、界面归因和可见上游链接形成书面结论。
- 对 AO 的 `web/server.js`、Provider 配置、本地 CLI、文件系统、工作流类型和公网 API 形成禁止清单；任何未列入白名单的原生路由默认不对公网发布。

**验收**：干净环境能按固定版本构建；法律/合规结论、派生边界、上游同步策略和可见归因均有证据。未通过时 `OPC-01` 只能在开发环境存在，不可生产开放。

### OPC-01 New API 顶栏入口与后台开关

**目标**：在不改变现有导航模块行为的前提下增加“OPC”入口，并将入口状态作为后端强制策略。

**实现**：

- 扩展 `HeaderNavModules`：新增 `opc: { enabled: boolean, requireAuth: boolean }`，默认 `{ enabled: false, requireAuth: true }`。
- 新增站点配置 `OPC_PUBLIC_URL`，仅允许 HTTPS 的绝对 URL；生产值固定为 `https://opc.<主域名>`。公开 `/api/status` 仅返回经校验后的跳转地址，不返回服务令牌、内部地址或密钥。
- New API 顶栏与移动端导航在 `opc.enabled=true` 时显示“OPC”；未登录点击走 New API 正常登录流程，登录成功后继续到 `OPC_PUBLIC_URL/sso/start`。使用同窗口跳转，不能为该项设置 `target=_blank`。
- 后台“Header navigation”新增 OPC 开关和“要求登录”只读说明；保存后刷新 status 缓存。`HeaderNavModules.opc=false` 是 SSO 签发、模型调用和执行请求的服务端拒绝条件，不只是前端显示条件。

**接口与数据**：`GET /api/status` 增加 `opc_url`；管理员仍通过既有 `PUT /api/option/` 更新 `HeaderNavModules` 与 `OPC_PUBLIC_URL`，写操作保留 RootAuth 和审计。

**验收**：默认隐藏；后台开启后桌面/移动端显示；关闭后刷新立即消失；手工访问 OPC SSO 起点得到 `OPC_DISABLED` 而不是进入服务。

### OPC-02 子域名、反向代理和受控服务骨架

**目标**：建立 OPC 独立部署边界，禁止将 AO 原生单租户 Web 服务直接发布。

**实现**：

- 新建 `services/opc-service` 与独立 worker 镜像；前端静态资源、应用 API 和 worker 仅由该服务暴露。AO 作为受控引擎依赖，不以原生 `ao web` 对公网监听。
- 配置 `opc.<主域名>` 的 DNS、TLS、SNI 和反向代理；仅反向代理 OPC 公共 HTTP 路由，New API 内部服务接口位于私有网络。
- 定义最小环境变量模板：`OPC_PUBLIC_URL`、`NEW_API_BASE_URL`、`OPC_SERVICE_TOKEN`、`OPC_SESSION_SECRET`、`OPC_DATABASE_URL`、`OPC_STORAGE_ROOT`。密钥仅由部署环境注入，不写入仓库、浏览器、日志或 AO 数据目录。
- 反向代理加请求体限制、上传大小限制、速率限制、`X-Content-Type-Options`、CSP、HSTS 和仅允许同源 Cookie；禁用目录浏览和 AO 原生数据目录静态映射。

**验收**：公网仅可看到健康检查、SSO 起点和授权后的 OPC API；AO 原生 `/api/config`、Provider、CLI、Custom Provider、Claude 代理、文件系统和未授权运行接口均为 404/403。

### OPC-03 New API 一次性 SSO 与 OPC 会话

**目标**：用户只在 New API 注册/登录，进入 OPC 时不共享跨域 Cookie 或长期令牌。

**实现**：

- 增加浏览器授权端点：OPC `/sso/start` 生成随机 `state` 并写入短期、`HttpOnly`、`Secure`、`SameSite=Lax` Cookie，随后跳转到 New API 授权端点。
- New API 授权端点使用现有 `UserAuth` 验证当前会话、用户状态和 `HeaderNavModules.opc`，只接受预注册的 `redirect_uri`，签发 `audience=opc`、有效期不超过 5 分钟、仅可兑换一次的随机授权码。
- OPC `/sso/callback` 比对 state 后，通过 `OPC_SERVICE_TOKEN` 调用 New API 内部兑换接口；兑换成功才建立 OPC 会话。New API 只保存授权码哈希、用户 ID、state 哈希、回调地址、过期时间和消费状态。
- OPC 在读取会话、创建运行和继续运行前调用 New API 校验用户仍为正常状态且 OPC 开关仍开启；用户禁用、登出失效或开关关闭时销毁本地会话并拒绝操作。

**接口**：

- 浏览器：`GET /api/user/auth/opc/authorize`、`GET /sso/start`、`GET /sso/callback`。授权端点放在 `/api/user/auth` 下，以便接收 New API 已有的 refresh cookie；它不接受长期令牌作为 URL 参数。
- 内部：`POST /internal/v1/opc/sso/exchange`，仅服务令牌可调用，输入 `code`、`audience=opc`，返回最小 subject（`user_id`、`session_subject`、用户状态和回调校验字段）。授权码中的 state 由 New API 保存并在兑换时返回，不由 OPC 伪造。

**验收**：正常跳转；无登录、错误 state、错误 audience、错误回调、过期码、并发兑换、重复兑换和用户禁用均被拒绝；URL、浏览器存储和日志不含长期令牌或完整授权码。

### OPC-04 opc_core 用户隔离数据模型

**目标**：建立 OPC 自己的数据边界，不读取或写入 New API 业务表。

**实现**：

- 新增独立迁移，不改写现有 New API 表：`opc_sessions`、`opc_workflows`、`opc_runs`、`opc_run_steps`、`opc_assets`、`opc_prompt_assets`、`opc_audit_events` 和必要的幂等/队列表。
- 所有 OPC 归属表使用 `new_api_user_id bigint NOT NULL`；不建立指向 `new_api.users` 的跨库外键。当前 `cross_service_audit_events.user_id uuid` 与 New API 整数用户 ID 不兼容，新增 `new_api_user_id bigint` 后才可写入 OPC 审计；历史 UUID 字段不得被错误复用。
- 每个 API 查询、更新、删除、导出和 worker 消费都以会话中的 `new_api_user_id` 加过滤条件；客户端传入的 user ID 一律忽略。
- 运行、步骤、预扣、New API 请求和账务流水以字符串/UUID 引用关联，禁止跨库 JOIN 和直接余额更新。

**验收**：数据库 runtime 账号没有连接/访问 `new_api` 钱包、用户、渠道表的权限；两名用户互相猜测 ID、下载素材、重跑、删除和导出均失败；迁移可重复执行并可回滚。

### OPC-05 用户可用模型目录

**目标**：将 AO 的 Provider/模型选择替换为 New API 的受控目录。

**实现**：

- New API 内部目录接口只返回当前用户可用且满足 `enabled`、OPC 启用、能力、协议和价格版本约束的模型。目录项至少包含 `platform_model_id`、展示名称、Provider 标签、能力、参数档位、`price_version` 和协议适配器；不返回渠道密钥、内部渠道 URL 或成本机密。
- OPC 前端保留截图中未打叉的 Provider 与模型选择器，但数据只来自 OPC `/api/models`；Provider 是目录展示元数据，不能进入 AO 配置页。
- OPC 服务对模型 ID、能力、参数档位和价格版本二次校验。前端伪造、已停用、未授权或协议不匹配模型返回稳定错误码，不能绕过目录调用。

**接口**：`GET /internal/v1/opc/models?capability=<...>` 与 OPC 同源的 `GET /api/models?capability=<...>`；前者服务鉴权，后者会话鉴权。

**验收**：不同用户/组看到的模型目录正确；停用模型立即不可选且不可调用；响应和前端包中不存在 Provider API Key。

### OPC-06 受控模型调用、预扣、结算与退款

**目标**：让一次 OPC 模型步骤只通过 New API 执行并使用用户统一余额。

**实现**：

- 冻结内部调用状态机：`quote -> reserve -> invoke -> settle`；失败、取消、超时和审核拒绝使用 `release/refund`。每一步携带 `source=opc`、`new_api_user_id`、`opc_run_id`、`opc_step_id`、模型快照和最少参数摘要。
- New API 持有渠道选择、供应商凭证、价格版本、预扣和实际用量结算；OPC 只持有 reservation/request 引用和脱敏结果。禁止静默切换到不同 `platform_model_id` 或价格版本。
- `Idempotency-Key` 由 OPC 为 reservation、调用和结算分别生成并持久化；重复请求返回同一结果，不重复扣费或退款。
- 文本流式响应仅经 OPC 服务代理给已授权的原始会话；异步图像/视频/音频调用保存 New API request/task 引用，由 worker 轮询或回调后结算。

**接口**：在现有 `contracts/platform-integration.openapi.yaml` 增加 `audience=opc` 与 `source=opc`，并实现 `quote`、`reserve`、`invoke`、`settle`、`release/refund` 的 OPC 专用契约。该接口不得接收浏览器 Bearer token。

**验收**：成功只结算一次；上游失败、超时、取消、审核拒绝和 worker 重启均按规则释放/退款；New API 账单可由 `opc_run_id` 和 `opc_step_id` 追溯。

### OPC-07 AO 页面派生与危险能力剥离

**目标**：保留已确认页面体验，同时让 AO 成为多用户 SaaS 的受控前端和编排引擎。

**实现**：

- 从固定 AO 提交建立私有派生前端，保留工作台、专家库、创意库、提示生成、角色团队、模板、我的运行和创意出片；所有数据请求改为 OPC 同源 API。
- 删除而非仅隐藏截图红叉项：Provider 配置、用户自定义 API Key、Custom Provider、CLI 登录/转发、系统 Claude 配置、帮助/赞助/Star 外链、设置齿轮、分享链接及对应后端路由。
- 工作流 schema 只允许平台声明式 `llm`、`image`、`video`、`audio`、`tts`、条件和聚合步骤。拒绝 `command`、shell、任意本地文件读写、MCP、CLI Provider、任意 URL 回调和未审查插件。
- 所有用户文案纳入 i18n；模型下拉、空状态、无权限、运行中、失败和禁用状态完整可用。

**验收**：未打叉页面可访问且只展示当前用户数据；所有禁止能力在 UI、前端路由和服务端 API 三层不可用；导入恶意 YAML/工作流被验证器拒绝。

### OPC-08 工作流运行、任务状态与审计

**目标**：实现可恢复、可审计、按步骤计费的多角色/DAG 运行。

**实现**：

- 定义运行状态：`created`、`validated`、`reserved`、`queued`、`running`、`waiting_input`、`succeeded`、`failed`、`cancelled`、`refunded`；步骤状态与运行状态分离。
- 创建运行时冻结工作流版本、角色版本、模型目录快照、价格版本、参数摘要和用户 ID。worker 不信任页面提交的运行状态或费用。
- 实现并发限制、取消、超时、重试、死信、人工补偿与 worker 重启恢复；每个状态变化写 `opc_audit_events` 并关联 New API 预扣/请求/结算 ID。
- 我的运行、运行详情、从允许节点恢复、导出和删除必须以用户归属过滤；删除运行不删除 New API 已存在的账务审计。

**验收**：重复提交不重复运行；单步骤失败不冲销已成功步骤；重启后可继续或以可审计失败结束；跨用户读取/恢复/删除失败。

### OPC-09 专家库、创意库、提示生成与出片素材

**目标**：将保留页面接入隔离数据、受控工作流和素材生命周期。

**实现**：

- 专家库和平台模板可公开读取，但用户保存的角色、模板、提示词和收藏必须按 `new_api_user_id` 隔离；任何公开模板不带用户机密、运行结果或私有素材。
- 提示生成和创意出片都通过 `OPC-06` 模型调用；结果写 `opc_assets`，对象路径以用户/运行分区，下载仅返回短时签名 URL。
- 初期实现本地私有存储、大小/数量上限、保留期、延迟清理、失败清理和孤儿扫描；定义 COS/OSS/S3/MinIO 替换接口，但不在未验收前切换生产对象存储。
- ZIP 导出作为异步任务，逐文件做归属校验、记录审计并在过期后删除；不支持“通过路径”导出。

**验收**：创意结果、提示资产和 ZIP 在用户间完全隔离；删除/过期后原 URL 无法访问；存储/导出失败不会影响 New API 已完成账务。

### OPC-10 安全、隔离与端到端验收

**目标**：证明入口、身份、模型、余额、运行和素材闭环满足安全边界。

**必须自动化的场景**：

1. OPC 默认关闭、后台开关显示/隐藏、直接 URL 和 SSO/API 绕过均失败。
2. New API 注册/登录后进入 OPC；state 错误、码过期、重放、错误 audience 和用户禁用均失败。
3. 两名用户分别创建工作流、运行、素材和导出，所有越权读取/修改/删除/恢复均失败。
4. 已启用模型可执行；停用/未授权/伪造模型不可执行；浏览器、OPC 数据库和日志均找不到 Provider Key。
5. 成功、上游错误、超时、取消、审核拒绝、重复回调、重复结算和 worker 重启下，余额、预扣和账务流水可对账。
6. AO 原生 Provider、CLI、文件、MCP、配置、分享和红叉功能无公网路由。

**证据**：请求/响应脱敏捕获、数据库权限拒绝记录、E2E 截图、账务对照、迁移日志、依赖/密钥扫描、缺陷清单和回归命令输出。

### OPC-11 灰度部署、观测、备份和回滚

**目标**：以关闭开关即可止血的方式上线，不影响 New API 主业务。

**实现**：

- 上线前完成 `new_api`、`opc_core`、OPC 私有素材的独立备份和恢复演练；部署使用不可变镜像和固定提交。
- 监控 SSO 成功率、未授权/重放次数、模型目录失败、预扣/结算/退款、worker 队列、任务超时、跨用户拒绝和对象清理。日志统一关联 request、`opc_run_id`、`opc_step_id`、reservation 和 New API request ID。
- 灰度顺序：内部管理员验证 -> 少量正常用户 -> 全量开启导航。任一 P0/P1 问题先关闭 `HeaderNavModules.opc`，停止新 SSO/运行，再回滚 OPC 服务；不回滚 New API 钱包流水。

**验收**：从外网独立验证 DNS、TLS/SNI、反代和登录跳转；关闭开关后新流量被阻断；恢复演练后 OPC 数据、账务引用和素材元数据一致。

## 4. 开发与合并规则

- 每个工作包单独 Pull Request，说明关联的接口、数据库迁移、权限影响、测试命令、证据位置和回滚方式。
- `OPC-03`、`OPC-06`、`OPC-08` 的接口先更新 OpenAPI/状态图并经评审，再写调用方；禁止 OPC 直接访问 New API 数据库。
- 不得通过用户 API Key、跨域 Cookie、共享 AO 数据目录、浏览器直连 Provider 或静默模型替换来缩短实施路径。
- 未完成 `OPC-00` 许可证结论、`OPC-06` 账务验收和 `OPC-10` 安全验收前，OPC 开关必须保持关闭。

## 5. 与现有工作包的映射

| OPC 工作包 | 复用/扩展现有工作包 | 主要验收项 |
| --- | --- | --- |
| OPC-00 | WP-00、WP-01 | M01 |
| OPC-01 至 OPC-03 | WP-02、WP-03 | M02、M03、M04、M19 |
| OPC-04 | WP-02 | M05、M20 |
| OPC-05 至 OPC-06 | WP-04、WP-05、WP-06 | M06 至 M11 |
| OPC-07 至 OPC-09 | WP-07 至 WP-10 | M12 至 M18 |
| OPC-10 至 OPC-11 | WP-11、WP-12 | E2E-01 至 E2E-05、M19、M20 |

## 6. 当前开发快照（2026-09-23）

已落地的第一批代码只建立受控边界，OPC 开关默认关闭，不能据此开放真实用户：

- `OPC-01`：New API `HeaderNavModules.opc`、`OPCPublicURL` 管理设置、`/api/status` 的安全 URL 输出，以及 OPC 顶栏同窗口入口。
- `OPC-02`：`services/opc-service` 健康检查、开关状态检查和受控入口骨架；AO 原生 Web、Provider、CLI 和 worker 尚未暴露。
- `OPC-03`：New API `opc` audience 的短时一次性授权码、回调白名单、单次兑换和账号状态/会话版本校验；OPC 仅建立本地 HttpOnly 会话。

仍未完成且在完成前不得打开生产开关：`opc_core` 持久化会话和用户隔离、模型目录、预扣/结算/退款契约、AO 页面裁剪与 worker 受控执行、端到端隔离和发布演练。`services/opc-service` 当前使用内存会话存储，仅用于开发测试。
