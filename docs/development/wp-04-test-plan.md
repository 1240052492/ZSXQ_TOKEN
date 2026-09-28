# WP-04 测试计划：统一钱包报价、预扣、结算与退款

## 目标与验收范围

WP-04 对应 `M06`（统一钱包）、`M07`（预扣/结算/退款）、`M09`（同模型渠道容灾）、`M10`（价格版本冻结）、`M11`（受控模型代理）、`M13`（任务状态与幂等），并覆盖 `E2E-01` 至 `E2E-04` 的计费链路。画布适配层只能调用 New API 内部契约，不保存钱包余额、账本或供应商密钥。

合并门槛：所有 P0 用例必须有可复核证据；`M06/M07/M10/M11/M13` 任一关键用例失败时禁止合并；任何重复扣款、越权模型调用、价格快照漂移或失败未退款均为阻断缺陷。

## 前置条件与测试数据

- 使用本地 mock New API（不连接生产钱包、不使用真实支付数据）；服务 token、模型供应商 key 和用户凭证仅通过进程环境注入，日志不得出现原值。
- 固定 fixture：用户 `u-1`、任务 `t-1`、平台模型 `m-image-1`，能力 `image`，价格版本 `pv-1`，报价 100 quota；同一模型配置两个渠道 `ch-a/ch-b`。
- 每个请求使用稳定、长度不少于 16 的 `Idempotency-Key`；重复请求必须使用同一 payload，冲突场景使用相同 key 加不同 payload。
- 执行命令：`npm test --prefix services/super-canvas-adapter`、`python scripts/validate_contracts.py`、`git diff --check`。

## 测试矩阵

### 1. 数据层

| 编号 | 场景 | 证据与通过标准 |
|---|---|---|
| D01 | 报价快照持久化 | 记录 `platform_model_id/alias/capability/price_version/parameters`；任务创建后字段不可被后续模型目录或价格发布覆盖。 |
| D02 | 预扣与结算引用 | reservation 仅引用 `quote_id/task_id`，结算仅引用 `reservation_id/task_id`；画布数据中不存在 wallet/ledger/balance 表或字段。 |
| D03 | 结算流水幂等 | 相同结算 key+payload 只产生一个结果；相同 key 不同 payload 返回冲突，账务结果不变。 |
| D04 | 退款/释放守恒 | 成功：`charged + refunded = reserved`；失败、取消、审核拒绝：`charged=0` 且全额释放/退款。 |
| D05 | 失败回滚 | 代理调用失败后任务仍保存失败原因和 reservation 引用；重试不会创建第二笔预扣。 |

### 2. 功能与权限

| 编号 | 场景 | 证据与通过标准 |
|---|---|---|
| F01 | 模型目录过滤 | 仅返回 New API 已启用且 `canvas_enabled=true`、能力和协议适配器均匹配的模型；目录缺失时拒绝创建任务。 |
| F02 | 报价与价格版本 | 报价返回 `quote_id/price_version/estimated_quota`；草稿价格不可报价，发布后新任务使用新版本。 |
| F03 | 预扣权限边界 | 画布只能通过 `/internal/v1/reservations` 预扣；直接写钱包/账本或调用供应商 key 的请求被拒绝并记录审计事件。 |
| F04 | 代理调用校验 | 代理请求必须绑定 reservation、task 和 model snapshot；无效能力、模型或 reservation 返回 4xx/409，不产生调用。 |
| F05 | 真实用量结算 | 成功任务按 `actual_usage` 结算并释放差额；实际用量超过预扣额时拒绝结算并保留人工处理状态。 |
| F06 | 失败与人工审核退款 | `failed/cancelled/moderation_rejected` 均全额释放；失败码、审核结果和退款金额可审计。 |
| F07 | 渠道容灾 | 首渠道失败时只能切换同一 `platform_model_id` 且价格版本兼容的渠道；不同模型或不同价格规则不得静默替换，必须返回明确错误。 |
| F08 | 服务认证与敏感信息 | 缺失/错误 service bearer、过短幂等 key 被拒绝；响应、日志和 task snapshot 不包含供应商 secret 或完整授权码。 |

### 3. 模拟用户操作与数据流

| 编号 | 场景 | 操作与通过标准 |
|---|---|---|
| C01 | 正常画布任务 | 选择能力与模型 → 获取报价 → 确认 → 预扣 → 代理调用 → 成功结算；前端状态与后端 task/reservation/settlement 引用一致。 |
| C02 | 失败退款 | 模拟代理超时/供应商 5xx → 任务进入 failed → 自动 settlement；钱包只出现一次预扣和一次全额释放。 |
| C03 | 取消与审核拒绝 | 在调用前取消或审核命中违规 → 不调用供应商 → 结算为 released/refunded，素材和任务状态可追踪。 |
| C04 | 重复点击/网络重试 | 对确认、预扣、结算分别重复提交同一幂等 key；页面最终只显示一笔任务和一组账务结果。 |
| C05 | 改价并发 | 管理员发布 `pv-2` 后创建新任务；旧任务仍使用 `pv-1`，历史账单金额不变化。 |
| C06 | 渠道故障演练 | 首渠道不可用 → 同模型备用渠道成功；若备用渠道价格/能力不兼容，界面显示失败原因并退款，不自动替换。 |

### 4. Smoke 与静态检查

| 编号 | 命令/场景 | 通过标准 |
|---|---|---|
| S01 | `npm test --prefix services/super-canvas-adapter` | New API client、billing state machine、orchestrator 测试全通过。 |
| S02 | `python scripts/validate_contracts.py` | OpenAPI path、schema、幂等头和价格版本字段验证通过。 |
| S03 | 启动 mock New API 与画布适配层 | 服务健康检查通过；执行一条正常任务链路并保存 request/response 脱敏记录。 |
| S04 | `git diff --check` 与 secret scan | 无空白错误；不出现 bearer、供应商 key、密码或完整授权码。 |
| S05 | 重启恢复 | 在 reserved/queued 状态重启 worker 后可恢复或安全退款；不得产生第二次扣款。 |

## 证据文件与状态规则

测试报告写入 `docs/delivery/WP-04/test-report.md`，按 `D/F/C/S` 编号记录命令、环境版本、脱敏输入输出、结果和重现步骤。状态只能为 `planned/in_progress/passed/blocked`：缺少真实运行证据时只能是 `in_progress` 或 `blocked`，不能以静态代码阅读替代通过。

## 合并验收标准

1. D01-D05、F01-F08、C01-C06、S01-S05 均有证据；所有 P0 用例通过。
2. `price_version` 在报价、预扣、model snapshot、代理调用和结算链路中保持一致。
3. New API 是唯一钱包写入方；画布无余额/账本写权限，无供应商密钥暴露。
4. 成功、失败、取消、审核拒绝、超时和渠道故障均验证账务守恒与幂等。
5. 报告明确未执行项、阻断项和残余风险；未满足上述任一条时 PR 不得合并。

