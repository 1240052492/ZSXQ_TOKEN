# WP-00 测试执行报告（当前基线）

## 范围

- 工作包：`WP-00`
- 验收项：`M01`
- 执行角色：test-case / audit preparation
- 执行日期：2026-09-22
- 当前结论：`blocked`

## 阻断原因

并行审计报告 `docs/delivery/WP-00/source-audit.md` 已记录两个上游的 URL、分支和 commit SHA，但 `E:\ZSXQ_TOKEN` 仍未导入或归档对应源码、锁文件和构建制品。因此 F01 仅完成远端 commit 存在性记录，F02（干净环境最小构建）及本地可重建验证尚无法执行。WP-00 不得标记为 `passed`，后续生产性工作包也不得引用未归档的上游版本。

解除条件：将审计报告中的两个上游 URL、分支和 commit SHA 归档为机器清单并完成源码哈希校验；随后完成源码抓取、依赖/SBOM 盘点、许可证审查和接口差异报告。

## 已执行检查

| 编号 | 命令 | 结果 | 证据/说明 |
|---|---|---|---|
| S01 | `python scripts/validate_acceptance.py` | 通过 | `Acceptance matrix valid: 25 items; gate_mode=baseline` |
| S02 | `python scripts/check_license.py` | 按当前门禁预期阻断（exit 1），合规状态 pending | 输出 `License review is pending; production release remains blocked.`；生产放行必须保持阻断 |
| S03 | `.github/workflows/security.yml` 同等 `git grep` 凭据扫描 | 无命中 | 命令退出码为 1，表示 grep 未找到匹配；不得把退出码 1 当作扫描故障 |
| S04 | `git diff --check` | 通过 | 无空白错误 |

## 未执行检查

| 编号 | 原因 | 关闭时必须附带 |
|---|---|---|
| D01 | 远端 SHA 已在 `source-audit.md` 记录，但缺机器清单和源码哈希 | `commit-manifest.json`、源码目录哈希 |
| D02-D04 | 未归档锁文件、SBOM 和本地迁移对象清单 | 依赖清单、SBOM、迁移对象清单 |
| F01 | 远端 commit 存在性已由审计报告记录；本地固定来源重建未执行 | 可复核的克隆/归档日志和 SHA 校验 |
| F02-F05 | 无本地固定源码和构建入口 | 两个上游的重建日志、账号/钱包/供应商路径盘点、接口差异和风险表 |
| C01-C04 | 无本地真实调用链可追踪 | 身份、钱包、模型/任务、素材/密钥的调用链证据 |

## 合并判断

本报告只能作为当前 `in_progress/blocked` 证据，不能支持把 `M01` 改为 `passed`。WP-00 的 PR 仍需关联 `M01`，补齐测试计划中列出的全部证据，并通过 Acceptance、Security、License Review 三个状态检查。
