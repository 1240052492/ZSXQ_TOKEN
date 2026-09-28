# Loop 状态交接契约

- **当前任务阶段**：`LOOP-ENV-01` 已创建；等待只读部署审查完成后，从本地代码构建镜像并部署到 Lisa
- **任务分支**：`loop/init-framework-baseline`
- **最大循环次数**：5
- **当前 loop 次数**：0 / 5
- **Orca Run**：`run_c8c3ecf21d41`
- **活动 Dispatch**：`ctx_1e71563089fc`（deployment-auditor）、`ctx_5d93c962a8dc`（acceptance-test-author）
- **接力会话**：Orca terminal `term_3d475c4d-c567-4b91-ae44-9ac3f24a9526`，已确认 `turn_started`；旧的自动更新阻塞终端已关闭
- **已完成项**：
  - [x] 已确认集成模式、身份/密钥边界、计费规则和生产门禁要求
  - [x] 已创建任务分支，未触碰 `main` 或基础设施配置
  - [x] 已确认仓库已有 `npm test` 相关验收、合同、服务测试和 smoke test 入口
  - [x] 已创建根级 `AGENTS.md`、`.loop/config.json`、任务、证据、日志和历史目录
  - [x] 已建立并运行统一 lint 命令
  - [x] 已完成 staged diff 复核并创建初始化提交 `d4a5478`
  - [x] 已创建 `LOOP-SRC-01` 任务文件，限定为只读来源/许可证/能力核查
  - [x] 已通过 SSH 只读核验 Lisa 的 Ubuntu、Docker、磁盘和现有服务
  - [x] 已停止并永久删除 Lisa 上的 bbs-go 与 person-dashboard 项目、容器、卷、镜像和项目目录
  - [x] 已永久删除已确认的项目备份和站点级 Nginx 配置
  - [x] 已使用 Let's Encrypt 为根域名、www、token、canvas、opc 申请证书并启用自动续期
  - [x] 已将 Lisa 清理证据写入 `.loop/evidence/LOOP-ENV-00-lisa-cleanup.md`
  - [x] 已核查本地 New API/TapCanvas 来源文件和 TapCanvas 禁止能力入口
  - [x] 已记录 agency-orchestrator 缺失及 GitHub 网络不可达证据
  - [x] 已从 GitHub 获取 agency-orchestrator 最新 `main`，固定 commit `0b41c9895b5ef1b70938999f2ada1b3637583574`
  - [x] 已安装 Node.js 22.18.0，并用 Node22 完成根项目回归测试
  - [x] agency-orchestrator TypeScript build 通过
  - [x] 已按 3/3 loop 停止，保留 Windows 上游测试阻塞证据
  - [x] 已将 `$orchestration` skill 的 Orca、角色、DAG、决策门和交接规则纳入 Loop 设计
- **未完成/待办项（Next Steps）**：
  - [x] 完成本任务的文件结构和命令基线
  - [x] 运行 `npm run loop:lint`、`npm test`、`git diff --check`
  - [x] 由协调者复核 diff 并提交初始化任务
  - [x] 读取 `AGENTS.md`、本文件和 `01-source-compatibility-baseline.md` 后执行只读核查
  - [x] 产出源码、许可证和禁止能力证据；已按规则停止后续实现
  - [x] 人工确认 agency-orchestrator 来源和最新 commit
  - [ ] 处理活动 worker 的只读报告
  - [ ] 从当前本地代码冻结构建上下文，构建并传输 Lisa 所需镜像
  - [ ] 在 Lisa 上部署新项目栈并执行正式化测试；当前 Nginx 已停止且没有应用路由
  - [ ] 人工决定在 Linux/WSL/Docker 中执行上游全量测试，或批准独立 Windows 测试兼容性补丁
  - [ ] 安全审查 agency `npm ci` 报告的 14 个依赖漏洞
  - [ ] 阻塞解除后，再细化 New API Key 绑定 API、SSO 回调和计费账本合同
  - [x] `LOOP-ORCH-00` 流程设计验收通过；实际 Orca 派发仍需 runtime 可用并单独创建任务
- **当前阻塞与踩坑提示（Blockers & Context）**：
  - ⚠️ 当前仓库之前已有未提交业务/文档改动，本任务不得回滚或覆盖；初始化提交必须只包含本任务声明的文件。
  - ⚠️ 基础设施尚未启动；任何 Docker、数据库、DNS、TLS、部署或密钥变更均需人工逐项确认。
  - ⚠️ 业务验收矩阵中的项目仍以 `planned`/`in_progress` 为准，不得因适配层测试通过而宣称 New API、SSO、真实计费或生产验收完成。
  - ⚠️ 新会话必须先读取 `AGENTS.md` 和 `STATE.md`，再加载当前任务。
  - ⚠️ `vendor/agency-orchestrator` 已获取固定 commit，但完整测试仍需在 Lisa Linux 环境重新执行。
  - ⚠️ TapCanvas 本地工作树包含大量既有修改，且源码含 child_process、MCP、API Key、文件写入和回调入口；未经安全裁剪不得上线。
  - ⚠️ 当前 Node.js 为 `v24.18.0`，项目契约声明 Node 22；测试在 Node 24 通过，但 Node 22 基线尚未复现，不得据此放行集成或生产。
  - ⚠️ Node22 已安装并用于根项目回归；agency 全量测试仍被 Windows POSIX `agy` fixture 阻塞，不能宣称上游测试通过。
  - ⚠️ agency 依赖审计报告 14 个漏洞（1 low、3 moderate、10 high），未完成安全审查前不得生产接入。
  - ⚠️ Lisa 根盘仍为 20GB，当前约 7.7GB 可用；部署前需控制镜像、依赖、日志和测试产物占用。
  - ⚠️ 新会话必须先读取 `AGENTS.md`、`STATE.md` 和 `.loop/tasks/03-lisa-deployment-validation.md`，再使用现有 Orca Run 继续；不得创建重复 Run 或重复 Dispatch。
- **测试结果**：根项目 Node22 `npm test` 通过；agency `npm run build` 通过；agency 全量 `npm test` 被 Windows POSIX fixture 阻塞
- **Lint 结果**：根项目 Node22 `npm run loop:lint` 通过，18 个 JavaScript 文件；`git diff --check` exit 0
- **变更文件**：`.loop/tasks/03-lisa-deployment-validation.md`、`.loop/evidence/LOOP-ENV-00-lisa-cleanup.md`、`STATE.md`
- **最后提交**：无新的代码提交；已创建 `LOOP-ENV-01` 和 Orca Run，当前仍处于部署前审查阶段
- **下一会话启动指令**：请读取 AGENTS.md 和 STATE.md，加载当前任务，从上次中断的地方继续。

## LOOP-BASELINE-01 顺序调整（2026-09-28）
- 已采纳先冻结代码基线再部署的方案；新增任务 `.loop/tasks/04-code-baseline-acceptance.md`。
- 执行顺序：恢复并验证 Orca runtime -> 结算现有 LOOP-ENV-01 审查 Dispatch -> 顺序执行 LOOP-BASELINE-01 -> 记录 checkpoint commit -> 再恢复 LOOP-ENV-01 部署流程。
- LOOP-BASELINE-01 不执行 Lisa、Docker 传输、DNS/TLS/Nginx、服务启动或真实模型调用；checkpoint commit 不代表部署或生产验收通过。
- Loop 上限已统一为任务级 `effective_max_loops: 5`；`.loop/config.json` 的全局默认值为 5，不再保留 3/5 双来源。
- 当前阻塞仍为 Orca runtime 不可用；不得在 runtime 恢复前创建重复 Run/Dispatch 或并行修改本地工作区。

## Orca runtime 恢复尝试（2026-09-28）
- 执行：`orca open --json`。
- 结果：返回 `runtime_open_timeout`，提示等待 Orca desktop window 超时；随后 `orca status --json` 仍为 `app.running=false`、`runtime.state=not_running`、`reachable=false`、`runtimeId=none`。
- 影响：无法读取或结算既有 Run `run_c8c3ecf21d41` 的两个 Dispatch；按 orchestration 硬停止条件，不创建重复 Run/Dispatch，不进入基线独立审查，不创建 checkpoint commit。
- 下一步：人工恢复 Orca desktop/runtime 后，先读取并结算现有 Dispatch，再按 `.loop/tasks/04-code-baseline-acceptance.md` 执行 `LOOP-BASELINE-01`。

## Worker 截图核验（2026-09-28）
- 用户提供的 `worker-task_1bb773085b1e` 和 `worker-task_b4d14e5acb94` 截图显示两个 worker 都以“任务未完成”文本结束，未生成各自要求的 evidence 报告，也未显示 `worker_done`。
- 截图仅是 worker 输出证据，不替代 Orca lifecycle 状态；当前 CLI 仍返回 runtime `not_running` 和两个 Dispatch `runtime_unavailable`。
- 结论：两个 Dispatch 不能标记 succeeded，也不能直接 retry、release 或 abandon；等待 Orca runtime 恢复后按 recovery 流程处理。

## 用户授权：放弃并重派（2026-09-28）
- 用户已明确授权放弃现有 `ctx_1e71563089fc` 和 `ctx_5d93c962a8dc`，随后在同一 Run `run_c8c3ecf21d41` 重新执行同等任务。
- 当前未执行 abandon 或重派：Orca runtime 仍不可用；`worker-abandon` 需要可达 runtime，且不得在未确认运行时状态时盲目重放。
- runtime 恢复后的固定顺序：`worker-list --run run_c8c3ecf21d41 --include-remote` -> 两次 `worker-abandon --dispatch ...` -> 确认旧 Dispatch 已 fenced -> 使用原 Task 的 `worker-start --task ... --retry-of ...`，显式指定 `--worktree current`、`--agent codex` 和同一 Run。

## 新 Run 请求阻塞（2026-09-28）
- 用户要求创建新 Run 并重新派发两个任务。
- 已执行 `orca open --json`，结果为 `runtime_open_timeout`；随后 `orca status --json` 仍为 `runtime.state=not_running`、`reachable=false`、`runtimeId=none`。
- 结论：新 Run 尚未创建，两个任务尚未派发；等待 Orca runtime 可达后再执行 `run-create` 和两次 `worker-start`。
