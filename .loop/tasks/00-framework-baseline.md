# LOOP-INIT-00：Loop 工程基线

## 目标

在不修改业务实现、基础设施和生产配置的前提下，建立本仓库可复用的 Loop Engineering 运行契约。

## 范围

- 根级 `AGENTS.md`、`STATE.md`。
- `.loop/config.json`、本任务文件和证据/日志/历史目录占位文件。
- 根 `package.json` 中统一 lint 命令及其最小实现。

不包含 New API、TapCanvas、agency-orchestrator 的业务接入，不包含 Docker、数据库、DNS、TLS、部署和密钥变更。

## 验收标准

- `INIT-01`：Loop 配置可被 JSON 解析，声明任务级 `effective_max_loops=5`、任务硬出口和生产独立门禁。
- `INIT-02`：新会话指令、分支保护、基础设施人工确认和协调者唯一更新 `STATE.md` 规则已写入静态契约。
- `INIT-03`：`npm run loop:lint` 返回 0，且没有新增 JavaScript 模块语法错误。
- `INIT-04`：`npm test` 返回 0，且输出可复现、未包含敏感凭据。
- `INIT-05`：初始化 diff 不包含基础设施、业务源码或受保护分支改动。

## 命令

- 测试：`npm test`
- Lint：`npm run loop:lint`
- effective_max_loops: 5
- 辅助检查：`git diff --check`

## 循环和停止条件

- `effective_max_loops=5`，计数由协调者维护，子任务重试不得重置。
- 若任一硬出口命令失败，进入失败分析并最多重试四次；第五次仍失败立即标记 `blocked` 并请求人工介入。
- 若发现需要基础设施或业务范围外修改，立即停止并登记阻塞，不扩大本任务范围。

## 交付物

- `.loop/evidence/LOOP-INIT-00-report.md`
- 更新后的根 `STATE.md`
- 只有在所有验收项通过且协调者完成 diff 复核后，才允许创建任务提交。
