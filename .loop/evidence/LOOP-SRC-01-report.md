# LOOP-SRC-01 只读核查报告

## 核查环境

- 分支：`loop/init-framework-baseline`
- 核查日期：2026-09-27
- 方式：只读文件检查、Git 状态/版本检查和远端可达性检查；未下载、合并或启动外部服务。

## 来源与许可证

| 项目 | 来源 | 当前证据 | 结论 |
| --- | --- | --- | --- |
| New API | `https://github.com/QuantumNous/new-api` | `vendor/new-api/LICENSE`、`NOTICE`、`THIRD-PARTY-LICENSES.md`、`go.mod` 存在；目录未被识别为独立 Git 工作树，无法从该目录固定上游 commit | `blocked`：需人工确认实际来源 commit 和许可证审查结论 |
| TapCanvas | `https://github.com/1240052492/TapCanvas` | 本地 Git commit `c2c825a3855247441f9a8a1fa057fc275d5ca72e`；`LICENSE` 存在，顶层 `NOTICE` 缺失；工作树有大量既有修改 | `blocked`：需清洁、可复现的固定来源和 NOTICE/依赖清单 |
| agency-orchestrator | `https://github.com/1240052492/agency-orchestrator` | `vendor/agency-orchestrator` 不存在；`git ls-remote` 因当前环境无法连接 GitHub 443 失败 | `blocked`：需人工提供可访问的固定 commit、许可证和源码快照 |

远端查询失败属于环境阻塞，不把记忆中的或文档中的 commit 当作当前已验证事实。

## 禁止能力证据

在 `vendor/TapCanvas`（排除 `node_modules` 和 `dist`）发现：

- `apps/hono-api/_extract_lastframe.cjs` 使用 `node:child_process`/`execFile`。
- `apps/hono-api/src/platform/node/agents-bridge-autostart.ts` 使用 `spawn` 启动桥接进程。
- `apps/agents-cli/src/bridge/mcp-gateway.ts` 和相关路由包含 MCP 转发。
- `apps/hono-api/scripts/*.mjs` 存在 `fs.readFileSync`/`fs.writeFileSync`。
- `apps/agents-cli` 和 `apps/hono-api` 存在 API Key、内网回调和外部 HTTP/worker 入口。

这些结果只能说明需要隔离和裁剪，不能作为已经完成安全封装的证明。后续必须在 UI、API、worker、反向代理四层拒绝 CLI/Shell、任意文件系统、任意 URL 回调、未审核 MCP/插件和用户 Provider/API Key。

## 本任务硬出口

| 命令 | 结果 |
| --- | --- |
| `python scripts/validate_acceptance.py && npm run loop:lint` | 首次直接在 Windows PowerShell 执行失败，原因是该 shell 不支持 `&&`；非项目测试错误 |
| `npm run loop:validate; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; npm run loop:lint` | 修正后的 PowerShell 命令通过，exit 0 |
| `git diff --check` | 通过，exit 0；仅报告既有文件的换行符提示 |

## 阻塞与停止结论

`SRC-01`、`SRC-02`、`SRC-03` 的关键来源/许可证/边界证据不完整；按任务停止标准标记 `blocked`。在人工确认来源、许可证和 agency-orchestrator 快照前，不允许进入 `WP-02`/`OPC-01` 合同实现、SSO、计费或生产配置。
