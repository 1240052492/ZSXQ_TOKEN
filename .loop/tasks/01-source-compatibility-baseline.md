# LOOP-SRC-01：源码兼容性、许可证与运行边界基线

## 目标

为 New API、TapCanvas 和 agency-orchestrator 固定可复核的来源版本、许可证信息和原生能力边界，确认后续集成不会误把未经审核的原生入口暴露给用户。

## 范围

- 只读核查 `vendor/new-api`、`vendor/TapCanvas` 及目标 agency-orchestrator 远端提交。
- 记录上游 commit、许可证/NOTICE、构建入口和可见的 Provider/CLI/Shell/文件系统/回调/MCP 能力。
- 输出来源基线、许可证清单和风险/阻塞登记。

不下载或合并未经确认的源码，不修改业务代码、数据库、Docker、部署、DNS、TLS、密钥或受保护分支。

## 验收标准

- `SRC-01`：记录三个项目的明确来源 URL 和 commit；远端不可访问或 commit 不可固定时标记 `blocked`。
- `SRC-02`：每个来源的许可证和 NOTICE 可定位；缺失或兼容性未审查时标记 `blocked`，不得猜测许可证。
- `SRC-03`：形成禁止能力清单，并为每项记录源码路径、入口和后续隔离策略；未取得源码时标记为待核验。
- `SRC-04`：记录每个来源的可复现构建/测试命令；命令需要外部基础设施时不启动，只登记前置条件和人工确认点。
- `SRC-05`：任务测试命令和 lint 命令返回 0；任何来源/许可证/边界阻塞均保留证据并停止后续实现。

## 命令

- 测试（PowerShell）：`npm run loop:validate; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; npm run loop:lint`
- 辅助核查：`git ls-remote`、`git status --short --branch`、许可证文件只读扫描
- effective_max_loops: 5

## 循环和停止条件

- `effective_max_loops=5`，共享协调者计数。
- 远端不可访问、许可证无法定位、源码能力无法审查或需要基础设施变更时立即记录 `blocked`，不以猜测替代证据。
- 达到 5 次失败仍无法获得证据时停止并请求人工确认来源、许可证和导入方式。

## 交付物

- `.loop/evidence/LOOP-SRC-01-report.md`
- 更新后的根 `STATE.md`
- 若解除阻塞，才允许创建下一个 `WP-02`/`OPC-01` 合同任务。
