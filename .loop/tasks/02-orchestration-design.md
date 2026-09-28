# LOOP-ORCH-00：Orchestration skill 纳入 Loop 工程

## 目标

把 `$orchestration` skill 的真实 Orca runtime、角色分工、DAG、决策门、worker done/escalation 和交接规则纳入项目级 Loop 契约。

## 范围

- `AGENTS.md` 的 orchestration 静态规则。
- `.loop/config.json` 的 runtime、角色、报告和决策门配置。
- `docs/development/loop-orchestration.md` 设计说明。
- 本任务证据和 `STATE.md` 交接。

不包含 Orca runtime 启动、worker 派发、业务代码、Docker、数据库、DNS、TLS、部署或密钥变更。

## 验收标准

- `ORCH-01`：明确真实 Orca runtime 要求、CLI 解析和 `skills get/status` 启动顺序。
- `ORCH-02`：定义 coordinator、developer、test-case-author、test-executor、acceptance-reviewer、security-audit-reviewer 和 human approver 的职责边界。
- `ORCH-03`：定义 work package 字段、任务 DAG、共享 loop 计数、worker done/escalation 协议。
- `ORCH-04`：定义 scope、实现测试、验收安全、生产人工批准四层决策门。
- `ORCH-05`：定义 `STATE.md` 唯一写入者、证据目录、会话交接和运行时不可用时的阻塞策略。
- `ORCH-06`：`npm run loop:validate`、`npm run loop:lint` 和 `git diff --check` 返回 0。

## 停止条件

- effective_max_loops: 5；本任务只允许流程文档和配置变更。
- Orca CLI/runtime 不可用时不尝试猜测命令或切换到普通 subagent，不影响本设计任务，但实际派发任务必须标记 `orchestration_blocked`。
