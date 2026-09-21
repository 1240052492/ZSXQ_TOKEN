# ZSXQ_TOKEN

New API + AI 超级画布整合项目的验收基线与合并门禁。

本仓库当前保存需求追踪、验收目标、证据模板和 CI 门禁；它不代表业务系统已经实现或验收通过。实现仓库必须在 Pull Request 中关联本仓库的验收编号和证据。

## 合并要求

每个 Pull Request 必须：

1. 说明受影响的验收编号（例如 `M07`、`E2E-02`）。
2. 更新 `docs/acceptance/matrix.json` 中对应项的状态和证据。
3. 通过 `Acceptance Gate`、`Security Gate`、`License Review Gate`。
4. 对钱包、SSO、权限、模型/价格、迁移和合规变更获得 CODEOWNERS 审批。
5. 不得把未执行的设计目标标记为 `passed`；没有可复核证据只能是 `planned` 或 `blocked`。

## 验收文档

- [模块验收目标](./ZSXQ_整合项目_模块验收目标.md)
- [结构化验收矩阵](./docs/acceptance/matrix.json)
- [代码合并标准](./docs/acceptance/merge-policy.md)
- [证据记录模板](./docs/acceptance/evidence-template.md)
- [许可证审查记录](./docs/compliance/license-review.md)

## 状态定义

- `planned`：目标已定义，尚未完成验收。
- `in_progress`：已有实现或测试正在进行。
- `passed`：证据已归档且满足通过条件。
- `blocked`：存在明确阻断原因，禁止以此状态合并生产放行变更。
