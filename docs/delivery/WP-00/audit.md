# WP-00 源码、许可证与安全审计报告

## 结论

**状态：blocked，不得关闭 WP-00，也不得进入 WP-01/WP-02 的可执行实现阶段。**

当前仓库是验收矩阵和合并门禁基线，不包含 `QuantumNous/new-api` 或
`1240052492/LocalMiniDrama` 的源码、固定 commit、依赖清单或 SBOM。因此无法证明
整合边界、许可证义务、接口兼容性和本地账号/钱包/供应商直连路径已经完成审计。

本报告只记录审计事实和关闭条件，不代表业务代码已经实现或生产可用。

## 审计范围与执行记录

审计对象：当前 `main` 工作树（HEAD `03577fd`）及其验收/合并门禁文件。

执行时间：2026-09-22（Asia/Shanghai）。

已执行的只读检查：

| 检查 | 结果 | 证据 |
|---|---|---|
| 工作树与远端 | 当前远端为 `https://github.com/1240052492/ZSXQ_TOKEN.git`；工作树存在未提交的 `docs/development/work-packages.md` 修改和未跟踪 `docs/development/wp-00-test-plan.md` | `git status --short --branch`; `git remote -v` |
| 仓库内容 | 仅 17 个已跟踪文件，全部为文档、JSON、Python 脚本和 GitHub 工作流；没有两个上游项目的源码目录或子模块 | `git ls-files` |
| 验收结构 | 通过：`Acceptance matrix valid: 25 items; gate_mode=baseline` | `python scripts/validate_acceptance.py` |
| 许可证脚本 | 输出 pending 且返回成功；这只能说明文本标记存在，不能证明法律审查通过 | `python scripts/check_license.py` |
| 当前许可证记录 | `docs/compliance/license-review.md` 仍为 `pending`，审查人、日期、结论证据均为空 | `docs/compliance/license-review.md` |
| 生产源码基线 | 缺失 `docs/evidence/WP-00/` 及 `source-baseline.md`、`commit-manifest.json`、依赖清单、SBOM 等审计产物 | `git ls-files docs/evidence/WP-00` |
| 上游可复现性 | 当前仓库未记录两个上游的 SHA、分支、抓取时间或内容哈希；本轮网络抓取未形成可归档证据 | `docs/development/wp-00-test-plan.md` 要求的 D01/F01 |

## 审计清单

状态定义：`PASS` 表示有当前仓库中的可复核证据；`GAP` 表示尚未提供证据；`BLOCKER`
表示在 WP-00 关闭或生产合并前必须解决。

### A. 源码来源与构建边界

| 编号 | 检查项 | 状态 | 必需证据/关闭条件 |
|---|---|---|---|
| A01 | 固定 `new-api` URL、分支、完整 commit SHA、抓取时间和源码哈希 | BLOCKER | `docs/evidence/WP-00/source-baseline.md` 与 `commit-manifest.json` |
| A02 | 固定 `LocalMiniDrama` URL、分支、完整 commit SHA、独立私有派生仓/子模块关系 | BLOCKER | 同上，并记录上游同步策略、修改文件和发布责任边界 |
| A03 | 两个上游可从固定 SHA 在干净环境获取并完成最小构建/启动 | BLOCKER | F01/F02 的命令、版本、日志和失败重现记录 |
| A04 | 适配层、部署配置和闭源业务代码与 AGPL 组件边界明确 | BLOCKER | `interface-diff.md`、架构 ADR、发布拓扑和合规审查结论 |
| A05 | 运行时依赖、锁文件、基础镜像和工具版本可重建 | GAP | `dependency-inventory.json`、锁文件哈希、构建制品摘要 |

### B. 许可证与供应链

| 编号 | 检查项 | 状态 | 必需证据/关闭条件 |
|---|---|---|---|
| B01 | New API 的 AGPL-3.0 版本、修改范围、网络服务义务和源代码提供方案 | BLOCKER | 由负责人和合规/法务签署的 `license-review.md`，结论不能为 `pending` |
| B02 | LocalMiniDrama 派生仓、子模块及第三方依赖许可证逐项识别 | BLOCKER | 许可证清单、NOTICE/版权声明检查结果和责任人 |
| B03 | SPDX 或 CycloneDX SBOM 可由固定 commit 重建 | BLOCKER | `sbom.spdx.json` 或 `sbom.cdx.json`、生成工具/版本/命令 |
| B04 | 高风险许可证、未知依赖和禁止引入项有处置结论 | BLOCKER | 风险登记表，逐项为 accepted、remediated 或 blocked |
| B05 | 发布制品携带许可证/NOTICE 与源码提供入口 | GAP | 发布清单、制品检查和公开入口验证 |

### C. 账号、钱包、供应商与数据边界（静态审计）

| 编号 | 检查项 | 状态 | 必需证据/关闭条件 |
|---|---|---|---|
| C01 | LocalMiniDrama 没有第二套注册、登录、密码存储或用户主键来源 | BLOCKER | F03/C01 调用链报告，含文件/符号/接口定位 |
| C02 | 画布和其他业务只提交业务事件/结算请求，不写 New API 钱包余额或流水 | BLOCKER | 钱包权限矩阵、数据库角色导出、C02 调用链和拒绝测试 |
| C03 | 浏览器、画布服务和日志中不存在供应商密钥、长期 bearer token 或完整授权码 | BLOCKER | F03/C04 扫描报告、脱敏日志样本、运行时网络检查 |
| C04 | 模型目录、代理、报价、预扣和任务状态的接口契约有输入/输出/幂等语义 | BLOCKER | `interface-diff.md` 及后续 WP-02/WP-04/WP-05/WP-06 契约评审 |
| C05 | 三库三账号、迁移与跨库访问边界可独立审计 | BLOCKER | `migration-risk.md`、角色权限导出和禁止跨库 SQL 检查 |

### D. 现有合并门禁自身

| 编号 | 检查项 | 状态 | 风险/关闭条件 |
|---|---|---|---|
| D01 | `validate_acceptance.py` 校验矩阵结构、ID、工作包依赖和生产模式 P0/P1 | PASS（范围有限） | 只证明结构有效，不证明 evidence 链接存在或内容可信 |
| D02 | Acceptance Gate 执行真实源码构建、测试和证据文件完整性 | BLOCKER | 当前只运行矩阵脚本并检查验收文档非空；须增加证据路径/字段/目标状态一致性校验 |
| D03 | License Review Gate 在 `pending` 时阻止合并/生产 | BLOCKER | `scripts/check_license.py` 在 pending 时返回 0，导致工作流“通过”但生产仍应阻断；必须修正门禁语义或明确仅允许文档基线 PR |
| D04 | Security Gate 覆盖历史、未跟踪文件、依赖和运行时配置 | GAP | 当前仅 `git grep` 已跟踪文本且规则有限；需补充 secrets/dependency/SAST 扫描与结果归档 |
| D05 | 分支保护和必需检查有 GitHub API/设置导出证据 | GAP | `merge-policy.md` 的“已验证”是声明，不是仓库内可复核证据；须归档不含令牌的设置快照或审计链接 |
| D06 | CODEOWNERS 保护合规、钱包、SSO、模型、价格、迁移路径 | PASS（静态） | 需在真实源码进入仓库后复核路径覆盖和实际审批记录 |

## 已确认的阻断项

1. **P0：上游源码和固定版本缺失。** 无法完成来源、构建、接口、账号/钱包直连和许可证审计；M01 必须保持 `planned` 或 `blocked`，不得标记 `passed`。
2. **P0：许可证审查未完成。** 当前结论为 `pending`，没有责任人、日期、SBOM、第三方许可证或 AGPL 网络服务边界结论。
3. **P0：许可证 CI 存在假通过。** `license-check.yml` 只检查脚本退出码，而脚本对 pending 返回 0；这与“生产合规审查未通过即阻断”的合并规则不一致。
4. **P1：验收证据未被机器验证。** `validate_acceptance.py` 不检查 `evidence_links` 是否指向存在的报告，也不要求每个 `passed` 项的证据文件可读取；矩阵可被填成看似完整但不可复核的状态。
5. **P1：安全扫描范围不足。** 当前工作流不覆盖未跟踪内容、依赖漏洞、历史泄漏、二进制/构建制品和运行时日志；进入真实源码后不能作为完整供应链安全证明。
6. **P1：生产分支保护的当前状态缺少可复核导出。** 文档声称已启用保护，但仓库中没有设置快照、API 响应或带时间戳的审计附件。

## WP-00 关闭清单

只有以下项目全部完成，且 M01 有真实证据后，WP-00 才能由 `blocked`/`planned` 进入 `done`：

- [ ] 归档两个上游固定 SHA、分支、抓取时间、源码哈希和可复现获取方式。
- [ ] 归档干净环境最小构建/启动日志；失败项有重现步骤和解除条件。
- [ ] 归档依赖清单、锁文件摘要和 SPDX/CycloneDX SBOM。
- [ ] 完成 AGPL-3.0、LocalMiniDrama 派生仓和第三方依赖专项审查；`license-review.md` 有责任人、日期、结论和证据链接。
- [ ] 完成接口差异表、迁移风险表和不可复用代码/配置清单。
- [ ] 对本地注册、钱包余额/流水、供应商密钥、直连 URL 和跨库 SQL 完成静态调用链审计并归档结果。
- [ ] 修正或明确 License Review Gate 的 pending 行为，使生产合并不能因脚本返回 0 而假通过。
- [ ] Acceptance Gate 能验证 evidence 文件存在、链接可读、状态与证据一致；Security Gate 有足够的源码/依赖/历史扫描证据。
- [ ] 重新运行 `python scripts/validate_acceptance.py`、许可证门禁和安全门禁，并把完整输出保存到 `docs/evidence/WP-00/test-report.md`。
- [ ] 至少一名 CODEOWNER 和合规责任人复核本报告；所有 P0/P1 阻断项关闭后，才允许解锁 WP-01/WP-02。

## 对后续 PR 的合并要求

- WP-00 之前的文档/门禁修正 PR 可以合并，但不得声称业务实现完成或生产放行。
- 任何引入上游源码、依赖、迁移、服务账号、模型供应商或支付配置的 PR，必须关联 `WP-00`/`M01`，并附新增审计证据；不得仅凭代码存在或 HTTP 200 标记通过。
- 钱包、SSO、模型/价格、权限、迁移和合规变更必须同时通过 Acceptance、Security、License 三项检查，并取得 CODEOWNERS 审批。
- 在许可证结论、固定源码版本和证据链完成前，禁止将 `gate_mode` 切换为 `production`，禁止进入生产发布门槛。

