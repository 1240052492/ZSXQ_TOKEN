# LOOP-SRC-01 人工确认后续验证报告

## 来源与环境

- 来源：`https://github.com/1240052492/agency-orchestrator`
- 获取方式：GitHub `main` shallow clone
- 固定 commit：`0b41c9895b5ef1b70938999f2ada1b3637583574`
- 上游 `package.json`：版本 `0.19.2`，许可证声明 `Apache-2.0`
- 本地源码目录恢复为上游 clean worktree；没有把临时兼容性修改留在上游目录
- Node.js：官方 Windows x64 `v22.18.0`，npm `10.9.3`，安装位置为用户级目录
- Git Bash Unix 工具已存在；Docker daemon 可用但本任务未启动容器

## 执行结果

| 检查 | 结果 |
| --- | --- |
| agency `npm ci --ignore-scripts` | 通过；审计报告 14 个依赖漏洞（1 low、3 moderate、10 high），需安全审查 |
| agency `npm run build` | 通过，TypeScript 编译 exit 0 |
| 根项目 Node 22 `npm test` | 通过；验收矩阵 25 项、服务测试 18/2/4、smoke 5 项 |
| 根项目 Node 22 `npm run loop:lint` | 通过，18 个 JavaScript 文件，exit 0 |
| `git diff --check` | 通过，exit 0；仅报告既有文件换行符提示 |
| agency 全量 `npm test` | Windows 平台失败；见下方阻塞 |

## 全量测试阻塞

在 Windows 运行 agency 最新 clean 源码时，测试套件暴露两类上游测试/平台不匹配：

1. `test/spawn-cli.ts` 使用 POSIX 风格 `/usr/local/bin` fixture，原生 Windows `path.join` 结果不满足断言。
2. `test/antigravity-cli.ts` 创建无扩展名的 POSIX `agy` 脚本并要求 Windows `PATHEXT`/spawn 识别和执行；Windows 原生执行链无法满足该假设。

曾在工作树中做最小 exploratory patch 验证第一类问题，但已恢复上游 clean worktree，未将补丁冒充为上游已修复代码。Node22 与 Git Bash PATH 已统一，最终仍被第二类 Windows fixture 阻塞。

## Loop 停止

本次人工确认后的验证已达到 `3/3` loop：

- 第 1 轮：agency 测试缺少 Unix mock 命令。
- 第 2 轮：补齐 Git Bash PATH 后定位到 Windows POSIX path fixture。
- 第 3 轮：统一 Node22/Git Bash 并验证最小兼容性修复，仍被无扩展名 `agy` Windows fixture 阻塞。

按 Loop 规则停止继续修改/重试。需要人工决定：在 Linux/WSL 容器中执行 agency 全量测试，或批准提交独立的 Windows 测试兼容性补丁；同时需要安全审查上述 14 个依赖漏洞。
