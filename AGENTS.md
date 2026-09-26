# ZSXQ_TOKEN 项目规则

## 项目范围

本项目围绕 New API、TapCanvas（AI 漫剧）和 agency-orchestrator（OPC）构建独立服务集成。New API 是统一身份、管理员、模型目录、余额和计费来源；子项目通过受控服务接口和一次性 SSO 接入，不合并为 New API 的内部模块。

当前工作只允许在任务分支进行。禁止直接写入 `main`、`master` 或其他受保护分支，禁止自动 push、merge 和发布。

## 技术基线

- New API：Go 服务，作为统一身份、模型和账务系统。
- 集成适配层：Node.js ESM 服务，位于 `services/`。
- 合同和验收检查：Python 脚本，位于 `scripts/` 和 `contracts/`。
- 本地验证：Node.js 22、Python 3、Docker Compose（仅在获得基础设施变更确认后运行或修改）。

## 业务红线

- 仅允许使用 New API 已开放且当前账号有权限的模型和平台 Provider。
- 用户 API Key 不能传入子项目；子项目只接收经过授权的 `key_id`、作用域和短期服务凭据。
- Key 作用域至少区分子项目、能力（文字/图片/视频/音频）、模型、环境、配额、有效期和状态。
- 不允许用户自定义 Provider、用户填写上游 API Key、CLI/命令执行、任意 Shell、任意文件系统读写、任意外部 URL 回调、未审核插件或 MCP。
- 管理能力统一嵌入 New API 管理后台，不建立绕过 New API 权限的单用户后台。
- 账务按实际用量结算；多步骤工作流按节点预扣；上游失败、超时、用户取消和审核拒绝均退款；运行中任务固定创建时价格版本。
- 受控媒体存储 API 可以写入业务产物，但必须有租户隔离、路径穿越防护、大小/类型限制和清理策略。

## Loop 工程规则

- 当前初始化任务 `LOOP-INIT-00` 的 `max_loops` 为 3；跨服务实现任务只有在任务文件明确批准后才可使用 5。
- 每一轮按“修改 -> 测试 -> 失败分析 -> 重试”计数。达到上限必须停止并标记 `blocked`，保留证据并请求人工介入。
- 任务硬出口是声明的测试命令返回 0，且声明的 lint 命令相对任务基线没有新增错误。缺失、跳过或无法复现的检查不算通过。
- 生产发布另有门禁：验收矩阵、安全/权限检查、迁移审查、备份恢复证据、可观测性、回滚准备和人工批准全部完成后才可发布。
- 基础设施、部署、DNS、TLS、密钥、数据库、CI 保护策略等变更必须逐项取得人工确认；本任务只做只读检查和流程文件初始化。
- 多 Agent 并行时，只有协调者可以改写根 `STATE.md`；其他角色只能在 `.loop/evidence/` 写报告。

## Orchestration 协调规则

- 当任务涉及跨服务、认证、授权、计费、存储、安全审计、任务 DAG、决策门或需要等待/升级时，必须按 `docs/development/loop-orchestration.md` 使用 `$orchestration` skill 设计并记录协作过程。
- 需要真实协调时只能使用 Orca runtime；不得用普通 subagent、临时脚本或聊天记录冒充 Orca 状态。运行前先按 skill 规则解析 CLI，执行 `ORCA skills get orchestration`，再执行 `ORCA status --json`。
- 协调者负责冻结 work package、分派依赖 DAG、维护共享 loop 计数、等待 `worker_done`/escalation、主持决策门和唯一更新 `STATE.md`。开发、测试、验收、安全审计角色不得互相替代或自审。
- worker 只能修改任务声明的文件，并在 `.loop/evidence/` 记录 scope、命令、产物、结果和 blocker；未通过测试/lint、权限边界或证据完整性时不能报告完成。
- Orca CLI/runtime 不可用时必须明确标记 orchestration blocked，不得静默切换到非 Orca 协作；可继续的协调者只读规划也必须记录为未派发。

## 命令与证据

- `npm test`：完整本地 Loop 检查（验收矩阵、合同、服务测试和 smoke test）。
- `npm run loop:lint`：统一 JavaScript 模块语法检查。
- `npm run loop:validate`：验收矩阵和合同检查。
- `npm run loop:test`：适配层单元/集成测试。
- `npm run loop:smoke`：服务边界 smoke test。

每个任务必须在 `.loop/tasks/` 声明范围、验收 ID、测试/lint 命令、最大循环次数和停止条件；命令输出及关键上下文写入 `.loop/evidence/` 或对应 `docs/delivery/`，不得把密钥、密码、完整 Cookie 或 `.env` 内容写入证据。

## 会话交接

结束任务或需要上下文切换前，协调者必须更新根 `STATE.md`，记录阶段、完成项、下一步、loop 次数、精确测试/lint 结果、阻塞点、变更文件和最后提交。新会话必须先执行：

> 请读取 AGENTS.md 和 STATE.md，加载当前任务，从上次中断的地方继续。
