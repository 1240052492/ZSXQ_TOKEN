# 代码合并标准

## 强制要求

`main` 只能通过 Pull Request 合并，必须满足：

- `Acceptance Gate / acceptance`、`Security Gate / secret-scan`、`License Review Gate / license-review` 全部成功；
- 至少 1 名审批人，且涉及受保护目录时必须通过 CODEOWNERS；
- 推送新提交后重新审批，解决全部 review conversation；
- 线性历史；禁止强制推送和直接删除 `main`；
- 钱包、SSO、模型、价格、权限、迁移和合规变更必须关联验收编号和证据。

机器可读配置见 [`merge-policy.json`](./merge-policy.json)。

## 当前远端状态

仓库为 `1240052492/ZSXQ_TOKEN` 私有个人仓库。GitHub API 对当前账户返回：

```text
HTTP 403: Upgrade to GitHub Pro or make this repository public to enable this feature.
```

因此仓库内容、CODEOWNERS、PR 模板和 CI 门禁已就绪，但 GitHub 服务器端 branch protection/rulesets 尚未启用。升级 GitHub Pro 或将仓库迁移到支持私有仓库保护规则的组织后，必须按 `merge-policy.json` 启用服务器规则；在此之前不得宣称合并门禁已强制生效。

## 启用命令

```powershell
$body = Get-Content .\docs\acceptance\merge-policy.json -Raw
# 使用 GitHub branch protection API 或仓库 Ruleset UI 按该文件配置。
```
