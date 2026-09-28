# Loop Engineering

本仓库把每一轮开发固定为一条可重复的闭环：

1. 从 `docs/development/work-packages.json` 选择一个未完成工作包，并在 PR 中声明对应的 `Mxx`/`Exx` 验收编号。
2. 先写或更新可复核的测试和证据目标，再实现最小变更。
3. 在仓库根目录运行 `npm test`。该命令依次执行验收矩阵检查、接口/数据库边界检查、三个服务的 Node 测试和冒烟测试。
4. 将真实输出、请求/任务/流水 ID 和环境信息记录到 `docs/delivery/<WP>/`，再更新 `docs/acceptance/matrix.json`。没有证据时只能使用 `planned`、`in_progress` 或 `blocked`。
5. 提交 PR，等待 `Acceptance Gate` 和 `Security Gate`；只有证据完整且门禁通过后，才能进入下一个工作包。

当前 `npm test` 验证的是适配层和契约边界，不等于 New API、支付渠道或公网环境已经完成验收。生产放行仍需按根目录验收目标执行真实 SSO、钱包、退款、渠道故障、备份恢复和合规演练。
