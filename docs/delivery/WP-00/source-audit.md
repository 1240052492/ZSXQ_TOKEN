# WP-00 源码、许可证与兼容性审计

## 审计范围与时间

- 审计对象：`QuantumNous/new-api`、`1240052492/LocalMiniDrama`。
- 审计时间：2026-09-22（Asia/Shanghai）。
- 审计方式：GitHub REST API、GitHub repository 页面、Raw 文件和本地 `E:\ZSXQ_TOKEN` 工作树只读检查；未读取或记录任何凭证。
- 本报告是源码基线和风险证据，不代表已经完成整合、业务实现或生产合规批准。

## 固定源码基线

| 项目 | 默认分支 | 当前 commit | commit URL | 仓库状态 |
|---|---|---|---|---|
| New API | `main` | `9310231b3c27fea933e939b46cf26e0ce67192e3` | <https://github.com/QuantumNous/new-api/commit/9310231b3c27fea933e939b46cf26e0ce67192e3> | public；分支页面显示 `protected=true`，但当前上游 required checks 为 off |
| LocalMiniDrama | `main` | `adaecf71a38277126fbe1e5e0d79664300f855c1` | <https://github.com/1240052492/LocalMiniDrama/commit/adaecf71a38277126fbe1e5e0d79664300f855c1> | public；GitHub API 标记为 fork，源仓库为 `xuanyustudio/LocalMiniDrama` |

**来源证据**

- New API repository API：<https://api.github.com/repos/QuantumNous/new-api>
- New API `main` branch API：<https://api.github.com/repos/QuantumNous/new-api/branches/main>
- LocalMiniDrama repository API：<https://api.github.com/repos/1240052492/LocalMiniDrama>
- LocalMiniDrama `main` branch API：<https://api.github.com/repos/1240052492/LocalMiniDrama/branches/main>

## 技术栈和关键路径

### New API

- Go 后端，Gin；前端 React 19、TypeScript、Rsbuild、TanStack、Tailwind CSS 4。
- 运行/部署支持 PostgreSQL、SQLite、MySQL；可选 Redis，另有独立日志库配置。仓库 README 明确说明 Docker Compose 默认包含 PostgreSQL + Redis。
- 关键认证与会话路径：`controller/auth_session.go`、`controller/oauth.go`、`middleware/auth.go`、`model/user_session.go`、`model/auth_flow.go`。
- 关键计费/钱包路径：`controller/billing.go`、`model/quota_reserve.go`、`model/topup.go`、`model/pricing.go`、`model/usedata_flow.go`、`controller/payment_*`。
- 关键模型/能力/渠道路径：`model/ability.go`、`model/model_meta.go`、`model/model_pricing_config.go`、`model/channel.go`、`model/channel_constraint.go`、`relay/channel/`。
- 关键异步任务/代理路径：`controller/task.go`、`controller/task_plugin.go`、`model/task.go`、`model/task_plugin.go`、`plugins/tasks/`、`middleware/task_plugin*.go`。
- 官方 README 还列出图像、音频、视频和 task plugin 接口，说明它具备承接画布代理层的基础，但不等于已经具备本项目要求的 `canvas_enabled`、能力标签和业务价格版本。

证据：<https://github.com/QuantumNous/new-api>（目录、技术栈、部署和协议说明），<https://api.github.com/repos/QuantumNous/new-api/git/trees/main?recursive=1>（源码树）。

### LocalMiniDrama

- `backend-node/`：Node.js 18+、Express、`better-sqlite3`、`jsonwebtoken`、`multer`、`sharp`、`adm-zip` 等。
- `frontweb/`：Vue 3、Vite、Element Plus、Pinia、Vue Router、`@vue-flow/core`。
- `desktop/`：Electron 28 和 electron-builder。
- 后端配置和持久化：`backend-node/configs/config.yaml`、`backend-node/src/config/index.js`、`backend-node/src/db/index.js`；当前实现使用单个 SQLite 文件、WAL 和本地目录。
- 画布/业务路由：`backend-node/src/routes/index.js`、`drama.js`、`storyboards.js`、`task.js`、`assets.js`、`upload.js`、`aiConfig.js`。
- AI 调用和本地供应商密钥边界：`backend-node/src/services/aiClient.js`、`imageClient.js`、`videoClient.js`、`aiConfigService.js`、`backend-node/src/routes/aiConfig.js`。
- 本地素材与导入导出：`assetService.js`、`uploadService.js`、`storageLayout.js`、`dramaExportService.js`、`dramaImportService.js`。
- 任务/恢复：`taskService.js`、`videoService.js` 及 22 个 SQLite migration；启动时会处理孤儿异步任务并恢复视频轮询。

证据：<https://github.com/1240052492/LocalMiniDrama>（架构、功能和目录说明），<https://api.github.com/repos/1240052492/LocalMiniDrama/git/trees/main?recursive=1>（源码树），以及该仓库的 `backend-node/package.json`、`frontweb/package.json` Raw/API 内容。

## 许可证与合规结论

### New API：AGPL-3.0，另有界面归因条件

- GitHub API 标记许可证为 `AGPL-3.0`；仓库 `LICENSE` 为 GNU Affero General Public License v3.0。
- New API README 明确要求修改版本保留作者归因 `Frontend design and development by New API contributors.`，并在交互界面保留指向原项目的可见链接：<https://github.com/QuantumNous/new-api>。
- AGPL 的网络服务场景、修改版本和对应源代码提供义务必须由法务针对最终部署形态确认。不能以“前端/后端拆成服务”或“只通过 API 调用”直接推断已脱离义务。
- 依赖许可证仍需在 WP-01 生成锁定版本 SBOM 后逐项核验；New API 自带 `NOTICE`、`THIRD-PARTY-LICENSES.md`，不得在整合时丢失。

证据：<https://github.com/QuantumNous/new-api/blob/main/LICENSE>、<https://github.com/QuantumNous/new-api#license>。

### LocalMiniDrama：MIT，但当前仓库是 fork

- GitHub API 标记许可证为 MIT；Raw `LICENSE` 声明 `Copyright (c) 2026 xuanyustudio`，并要求复制/实质部分保留版权与许可声明。
- 仓库页面显示 `1240052492/LocalMiniDrama` fork 自 `xuanyustudio/LocalMiniDrama`。因此 ZSXQ_TOKEN 的私有派生仓或子模块方案必须保留上游 MIT 通知，并确认对新增/修改代码的版权归属和发布策略。
- LocalMiniDrama 的 MIT 许可证本身不产生 AGPL 传染，但把其代码直接合入 New API 同一衍生作品仍需按 New API 的 AGPL 边界和界面归因规则做专项审查。

证据：<https://github.com/1240052492/LocalMiniDrama/blob/main/LICENSE>、<https://raw.githubusercontent.com/1240052492/LocalMiniDrama/main/LICENSE>、<https://github.com/1240052492/LocalMiniDrama>。

## 整合差异与必须保留的边界

| 领域 | 当前上游事实 | 对整合的约束 |
|---|---|---|
| 身份 | New API 有用户/会话/OAuth 体系；LocalMiniDrama 代码树是本地优先应用，存在本地 AI 配置和 JWT 依赖线索 | 画布不得保留第二套注册、密码、钱包或供应商密钥入口；采用 New API SSO 授权码并在画布仅保存用户 ID 映射 |
| 账务 | New API 已有 quota、reserve、pricing、topup、payment 和 usage 路径 | 画布只能提交业务事件/用量明细给 New API；禁止直接改余额或复制账务表 |
| 模型 | New API 有模型元数据、能力、价格配置、渠道约束和 task plugin | 目录必须由 New API 输出，并额外满足 `enabled && canvas_enabled && capability && protocol_adapter`；备用渠道只能绑定同一平台模型和价格版本 |
| 数据库 | New API 可用 PostgreSQL；LocalMiniDrama 当前是单 SQLite 数据库 | 生产使用同一 PostgreSQL 集群但 `new_api`、`opc_core`、`super_canvas` 分库、分账号、分 migration；不能把 LocalMiniDrama SQLite 表直接搬成共享业务表 |
| 存储 | LocalMiniDrama 当前本地文件/静态目录/ZIP 导入导出 | 首期本地 provider；后续通过抽象 provider 接 COS/OSS/S3/MinIO/CDN，管理员配置，用户不见密钥；需补保留期、容量、延迟清理和审计 |
| 任务 | LocalMiniDrama 有本地异步任务、重试和视频轮询；New API 有 task plugin/relay | 适配层要将画布任务 ID、节点状态和 New API reservation/settlement 关联，并补幂等键、失败退款、跨服务审计 |

## 当前阻塞与放行条件

1. **源码未导入/未锁定到 ZSXQ_TOKEN**：本地工作树只有验收文档和 CI 脚本，没有两个上游的源码或子模块。WP-01 前必须以本报告 commit 建立可重建的源码归档/子模块记录，且不得依赖漂移的 `main`。
2. **GitHub 上游分支保护不能作为本项目门禁证据**：New API API 当前显示 `protected=true` 但 required checks 为 off；LocalMiniDrama `main` 未保护。必须以 ZSXQ_TOKEN 自己的 PR checks、CODEOWNERS 和保护规则为准。
3. **AGPL 专项审查缺失**：在生产公开服务前，必须完成修改版本源代码提供、界面归因/原项目链接、NOTICE/第三方依赖和派生仓边界的书面审查；审查未完成时 M01/G0 必须保持 `blocked` 或 `planned`，不得标 `passed`。
4. **LocalMiniDrama fork 权利与维护策略未固化**：需决定并记录私有派生仓或子模块的上游同步、版权声明、贡献回流和发布方式；未确认前禁止将其代码直接复制进 New API 核心目录。
5. **认证、计费和模型能力接口尚未实现**：本报告仅证明上游存在可复用的基础路径，不证明 SSO、统一钱包、价格版本固化、`canvas_enabled` 过滤或不静默换模已完成。

## 审计命令记录（可复核）

```powershell
Invoke-RestMethod https://api.github.com/repos/QuantumNous/new-api
Invoke-RestMethod https://api.github.com/repos/QuantumNous/new-api/branches/main
Invoke-RestMethod https://api.github.com/repos/1240052492/LocalMiniDrama
Invoke-RestMethod https://api.github.com/repos/1240052492/LocalMiniDrama/branches/main
Invoke-RestMethod 'https://api.github.com/repos/QuantumNous/new-api/git/trees/main?recursive=1'
Invoke-RestMethod 'https://api.github.com/repos/1240052492/LocalMiniDrama/git/trees/main?recursive=1'
```

## WP-00 结论

**状态：blocked（阻塞后续实现放行，不是代码失败）**。

已完成源码、技术栈、关键路径和许可证事实审计；未完成的是将固定基线导入/归档、完成 AGPL 与 fork 权利专项确认，以及形成可重建的 SBOM/依赖清单。WP-01、WP-02 可以开始设计性工作，但不得以本审计作为生产发布或“WP-00 passed”的依据，直至上述放行条件有独立证据。
