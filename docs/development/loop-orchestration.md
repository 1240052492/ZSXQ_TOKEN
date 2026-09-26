# Loop Engineering Orchestration 设计

## 目的

将 `$orchestration` skill 作为 Loop Engineering 的多 Agent 协调层。它负责任务拆分、依赖 DAG、线程消息、worker 完成/升级、决策门和协调者循环；它不替代项目测试、验收矩阵、生产审批或人工基础设施确认。

## 何时必须使用

以下任一条件成立时，任务必须创建 orchestration work package：

- 跨 New API、TapCanvas、OPC、gateway 或 worker 的改动。
- 认证、授权、API Key 作用域、计费、退款、存储、迁移或安全边界。
- 需要多个角色并行、依赖 DAG、等待 worker 结果或人工升级。
- 需要在任务测试门和生产门之间保留独立审查证据。

单文件、低风险、可由单一角色在一个 loop 内完成的任务可以由协调者直接执行，但仍必须遵守 `AGENTS.md`、测试/lint 硬出口和 `STATE.md` 交接规则。

## Orca runtime 约束

`$orchestration` skill 要求使用真实 Orca runtime。开始派发前，协调者必须：

1. 解析本会话 CLI：优先 `ORCA_CLI_COMMAND`；其次按 skill 规则选择 `orca-dev`、`orca-ide` 或 `orca`。
2. 对选定 CLI 执行 `ORCA skills get orchestration`，读取当前版本的完整指南。
3. 执行 `ORCA status --json` 确认 runtime；需要启动时才执行 `ORCA open --json`。
4. 使用当前版本指南中的 task dispatch、thread、worker_done、escalation、decision gate 和 coordinator loop 命令。

不得猜测 Orca 子命令、复用过期文档、用普通 subagent/脚本模拟 worker 状态，或在 CLI 不可用时声称已经完成 orchestration。CLI/runtime 不可用时，任务状态为 `orchestration_blocked`，只允许保留只读规划和阻塞证据。

## 角色与权限

| 角色 | 责任 | 不允许 |
| --- | --- | --- |
| `coordinator` | 冻结 work package、维护 DAG/loop 计数、派发、等待、决策门、唯一更新 `STATE.md` | 直接跳过验收或替其他角色自审 |
| `developer` | 只改任务声明文件，实现最小变更 | 修改基础设施、越过依赖或改 `STATE.md` |
| `test-case-author` | 编写可复现测试和失败场景，映射 acceptance ID | 修改产品代码让测试通过 |
| `test-executor` | 在声明环境运行测试/lint，保存原始结果 | 把跳过、环境缺失或部分结果报告为通过 |
| `acceptance-reviewer` | 独立核对验收矩阵、证据和用户流程 | 自审开发者未验证的结果 |
| `security-audit-reviewer` | 审查 SSO、Key、Provider、文件、回调、MCP、权限和敏感数据 | 放宽业务红线或写入密钥 |
| `human approver` | 确认基础设施、生产发布、来源许可证和不可逆操作 | 由 Agent 代签 |

除协调者外，所有角色只能在 `.loop/evidence/` 写角色报告。协调者也不得覆盖其他角色报告，只能汇总事实。

## Work package 和 DAG

每个 work package 必须声明：

```text
id, objective, owner_role, allowed_files, dependencies,
acceptance_ids, test_command, lint_command, max_loops,
stop_conditions, evidence_paths, escalation_owner
```

推荐的项目 DAG：

```text
source/license baseline
        |
contracts + database boundary
        |
SSO/navigation ---- model catalog ---- controlled proxy
        |                 |                    |
        +------------ task/billing ----------+
                          |
                 TapCanvas / OPC adapters
                          |
              storage + moderation + E2E
                          |
          security/release/backup human gate
```

依赖未满足时不得派发下游 worker。当前项目的 `LOOP-SRC-01` 阻塞会阻止 `WP-02`/`OPC-01` 合同实现进入可执行状态。

## 协调者循环

每个 work package 最多 3 个 loop；跨服务任务只有任务文件明确批准才可使用 5。一个 loop 是：

1. 协调者读取 `AGENTS.md`、`STATE.md` 和任务文件，冻结范围和 acceptance IDs。
2. 通过 Orca dispatch 发送角色任务，要求每个 worker 返回结构化 done/evidence 或 escalation。
3. 测试执行者运行测试/lint；失败由协调者归因并决定一次重试、缩小范围或升级人工。
4. 达到成功条件后依次通过实现测试门、独立验收/安全门；任何关键证据缺失都保持 blocked。
5. 达到 `max_loops` 或遇到来源、权限、基础设施、许可证和 runtime 阻塞时立即停止，保存失败日志，不重置计数。

worker 的完成消息至少包含：`task_id`、`role`、`scope`、`changed_files`、`commands`、`artifacts`、`test_result`、`lint_result`、`blockers`、`next_action`。只有协调者在审查后才可将其映射为任务完成。

## 决策门

| Gate | 通过条件 | 失败动作 |
| --- | --- | --- |
| `scope-and-contract` | 输入版本、接口、权限、回滚和 acceptance IDs 已冻结 | 不派发开发 worker |
| `implementation-test-lint` | 声明测试返回 0，lint 无新增错误，loop 未超限 | 重试或标记 blocked |
| `acceptance-security` | 独立验收和安全审计报告齐全，禁止能力在 UI/API/worker/proxy 均拒绝 | 禁止合并/发布 |
| `production-human-approval` | 验收矩阵、迁移、备份恢复、观测、回滚和人工批准齐全 | 保持关闭开关，不发布 |

通过任务门不代表生产门通过。AI 漫剧和 OPC 默认关闭；任何生产灰度都必须先保留 New API 关闭开关和回滚路径。

## 状态与交接

协调者在每个小节完成、阻塞或会话切换前更新 `STATE.md`：当前任务、loop 次数、已完成、下一步、精确测试/lint、阻塞、变更文件、最近提交和下一会话指令。worker 只写角色报告，避免并发覆盖状态。

新会话固定注入：

> 请读取 AGENTS.md 和 STATE.md，加载当前任务，从上次中断的地方继续。

## 安全边界

- Orca 线程、日志、报告不得包含 API Key、密码、Cookie、完整 SSO code、`.env` 或 Provider secret。
- worker 不得共享用户数据或跨租户工件；产物引用使用脱敏 ID。
- 任何用户自定义 Provider、CLI/Shell、任意文件系统、任意外部回调、未审核 MCP/插件都必须在 UI、API、worker、proxy 四层拒绝。
- 需要基础设施或生产权限时只创建 escalation，不由 worker 自行修改。
