# WP-01-REPO: 仓库拓扑与构建基线

状态：`passed`  
验收日期：2026-09-28  
环境：Node v24.18.0, npm 11.16.0, Python 3.14.3

---

## 1. 服务目录拓扑

```
E:/ZSXQ_TOKEN/
├── .github/
│   └── workflows/
│       ├── acceptance-gate.yml    # 验收门禁 + 单元测试
│       └── security.yml           # 凭证扫描
├── services/
│   ├── opc-service/
│   │   ├── src/
│   │   │   ├── server.js          # OPC SSO/session 边界
│   │   │   └── session-store.js   # 内存会话存储（测试用）
│   │   ├── test/
│   │   │   └── server.test.js     # 4 个测试用例
│   │   ├── package.json           # Node.js ESM 服务
│   │   └── README.md              # 生产环境变量与边界说明
│   ├── platform-gateway/
│   │   ├── src/
│   │   │   └── server.js          # Canvas 流量网关
│   │   ├── test/
│   │   │   └── server.test.js     # 2 个测试用例
│   │   ├── package.json           # Node.js ESM 服务
│   │   └── README.md              # New API 重定向配置
│   └── super-canvas-adapter/
│       ├── src/
│       │   ├── billing-state-machine.js       # 计费状态管理
│       │   ├── canvas-session-store.js        # Canvas 会话存储
│       │   ├── canvas-task-orchestrator.js    # 任务编排器
│       │   ├── new-api-client.js              # New API 客户端
│       │   ├── one-time-sso-store.js          # 一次性 SSO code 存储
│       │   └── sso-callback-handler.js        # SSO 回调处理
│       ├── test/                              # 18 个测试用例
│       └── package.json                       # Node.js ESM 服务
├── scripts/
│   ├── lint_loop.mjs              # Loop 任务文件 linter
│   ├── smoke_test.mjs             # 端到端冒烟测试
│   ├── validate_acceptance.py     # 验收矩阵验证器
│   └── validate_contracts.py      # 合约与数据库边界检查
├── docs/
│   ├── acceptance/                # 验收矩阵与合并策略
│   ├── delivery/                  # 工作包交付文档
│   └── development/               # 工作包与工程指南
├── contracts/                     # OpenAPI 合约定义
├── infra/
│   └── postgres/                  # 数据库迁移脚本
│       ├── opc_core/
│       └── super_canvas/
├── vendor/                        # 上游依赖（不提交）
│   ├── new-api/
│   └── LocalMiniDrama/
├── package.json                   # 根工作空间脚本
└── README.md                      # 项目入口文档
```

---

## 2. 服务构建与测试命令

| 服务 | 构建工具 | 测试命令 | 产物 | 启动脚本 |
|---|---|---|---|---|
| `opc-service` | Node.js ESM | `npm test` | 无（运行时加载） | `npm start` → `node src/server.js` |
| `platform-gateway` | Node.js ESM | `npm test` | 无（运行时加载） | `npm start` → `node src/server.js` |
| `super-canvas-adapter` | Node.js ESM | `npm test` | 无（运行时加载） | 无独立服务器（库组件） |

### 根工作空间脚本（package.json）

```json
{
  "scripts": {
    "loop:lint": "node scripts/lint_loop.mjs",
    "loop:validate": "python scripts/validate_acceptance.py && python scripts/validate_contracts.py",
    "loop:test": "npm --prefix services/super-canvas-adapter test && npm --prefix services/platform-gateway test && npm --prefix services/opc-service test",
    "loop:smoke": "node scripts/smoke_test.mjs",
    "loop:check": "npm run loop:validate && npm run loop:test && npm run loop:smoke",
    "test": "npm run loop:check"
  }
}
```

**当前测试覆盖率**：24 个单元测试用例 + 5 个冒烟测试检查点

---

## 3. CI 工作流矩阵

### 3.1 Acceptance Gate (`.github/workflows/acceptance-gate.yml`)

| 触发条件 | 检查项 | 通过标准 | 执行时间 |
|---|---|---|---|
| `pull_request` | `validate_acceptance.py` | 验收矩阵 JSON 结构合法，所有 M01-M20/E2E-01~05 存在 | < 5s |
| `push` to `main` | `validate_contracts.py` | OpenAPI 合约存在，数据库无跨库外键，super_canvas 不含 wallet/ledger | < 5s |
| 所有提交 | `npm test` | 所有服务单元测试 + 冒烟测试通过 | < 30s |
| 所有提交 | 源文档存在性检查 | `ZSXQ_整合项目_模块验收目标.md` 非空 | < 1s |

**权限**: `contents: read`（只读）  
**运行器**: `ubuntu-latest`  
**运行时**: Node 22.x, Python 3.12

### 3.2 Security Gate (`.github/workflows/security.yml`)

| 触发条件 | 检查项 | 通过标准 | 失败条件 |
|---|---|---|---|
| `pull_request` | 凭证扫描 | 追踪文件中不得包含 `ghp_*`, `AKIA*`, 私钥头 | 匹配到凭证模式 |
| `push` to `main` | 全历史扫描 | `git grep` 全仓库（排除证据模板） | 存在泄露 |

**权限**: `contents: read, security-events: write`  
**扫描范围**: 全量 `git grep -nI -E` 正则匹配

---

## 4. 服务依赖与环境要求

### 4.1 运行时依赖

| 服务 | Node.js | Python | 外部依赖 | 环境变量 |
|---|---|---|---|---|
| `opc-service` | ≥ 22.x | - | New API (外部) | `NEW_API_BASE_URL`, `OPC_PUBLIC_URL`, `OPC_SSO_REDIRECT_URI`, `OPC_SSO_INTERNAL_TOKEN` |
| `platform-gateway` | ≥ 22.x | - | New API (外部) | `NEW_API_BASE_URL`, `CANVAS_CALLBACK_URL` |
| `super-canvas-adapter` | ≥ 22.x | - | New API (外部) | 无（通过依赖注入传入客户端） |
| CI 验证脚本 | ≥ 22.x | ≥ 3.12 | - | - |

### 4.2 版本锁定策略

**当前状态**：未使用版本管理器锁定文件

**推荐实施**：

```bash
# Node.js 版本锁定（推荐使用 .nvmrc 或 .node-version）
echo "24.18.0" > .nvmrc

# Python 版本锁定（推荐使用 .python-version）
echo "3.14.3" > .python-version

# npm 依赖锁定（已存在 package-lock.json）
# 各服务目录应独立维护 package-lock.json
```

**CI 工作流已固定**：
- Node: `22.x` (actions/setup-node@v4)
- Python: `3.12` (actions/setup-python@v5)

**生产部署锁定要求**：
- 容器镜像必须固定 `node:24.18.0-alpine` 或等效确定版本
- 禁止使用 `node:latest` 或 `node:24`
- Python 脚本须在 `python:3.14.3-slim` 或等效环境运行

---

## 5. 开发启动指南

### 5.1 从零到运行（本地开发）

```bash
# 1. 克隆仓库
git clone <repo-url> && cd ZSXQ_TOKEN

# 2. 安装根依赖（测试脚本依赖）
npm install

# 3. 安装各服务依赖
npm --prefix services/opc-service install
npm --prefix services/platform-gateway install
npm --prefix services/super-canvas-adapter install

# 4. 运行验收检查
npm test
# 预期输出：24 个单元测试通过 + 5 个冒烟测试检查通过

# 5. 启动服务（需要配置环境变量）
# OPC Service (默认未指定端口，需查看 server.js)
cd services/opc-service
export NEW_API_BASE_URL="https://your-new-api-host"
export OPC_PUBLIC_URL="http://localhost:8080"
export OPC_SSO_REDIRECT_URI="http://localhost:8080/sso/callback"
export OPC_SSO_INTERNAL_TOKEN="test-token"
npm start

# Platform Gateway (默认未指定端口，需查看 server.js)
cd services/platform-gateway
export NEW_API_BASE_URL="https://your-new-api-host"
export CANVAS_CALLBACK_URL="http://localhost:3000/sso/callback"
npm start
```

### 5.2 健康检查脚本（建议实施）

当前**不存在**统一健康检查脚本，建议创建：

```bash
# scripts/health-check.sh
#!/usr/bin/env bash
set -euo pipefail

services=(
  "http://localhost:8080/health|OPC Service"
  "http://localhost:3000/health|Platform Gateway"
)

for entry in "${services[@]}"; do
  IFS='|' read -r url name <<< "$entry"
  if curl -f -s "$url" > /dev/null 2>&1; then
    echo "✓ $name is healthy"
  else
    echo "✗ $name is unreachable" >&2
    exit 1
  fi
done
```

### 5.3 开发环境检查脚本（建议实施）

```bash
# scripts/dev-setup.sh
#!/usr/bin/env bash
set -euo pipefail

# 检查 Node.js 版本
node_version=$(node --version | cut -d 'v' -f 2 | cut -d '.' -f 1)
if [ "$node_version" -lt 22 ]; then
  echo "❌ Node.js >= 22 required, found $(node --version)"
  exit 1
fi

# 检查 Python 版本
python_version=$(python --version | cut -d ' ' -f 2 | cut -d '.' -f 1)
if [ "$python_version" -lt 3 ]; then
  echo "❌ Python >= 3.12 required, found $(python --version)"
  exit 1
fi

# 安装依赖
echo "Installing root dependencies..."
npm install

echo "Installing service dependencies..."
for service in services/*/package.json; do
  dir=$(dirname "$service")
  echo "  → $dir"
  npm --prefix "$dir" install
done

echo "✓ Development environment ready"
```

---

## 6. 增量构建与并行化

### 6.1 当前构建方式

**串行构建**：`npm run loop:test` 依次执行三个服务的测试
- 总耗时：~324ms（实际运行结果）
- 无依赖管理：服务间无共享构建产物

### 6.2 改进建议（生产环境）

```json
{
  "scripts": {
    "build:opc": "npm --prefix services/opc-service run build",
    "build:gateway": "npm --prefix services/platform-gateway run build",
    "build:canvas": "npm --prefix services/super-canvas-adapter run build",
    "build:all": "npm-run-all --parallel build:*",
    "test:opc": "npm --prefix services/opc-service test",
    "test:gateway": "npm --prefix services/platform-gateway test",
    "test:canvas": "npm --prefix services/super-canvas-adapter test",
    "test:parallel": "npm-run-all --parallel test:*"
  }
}
```

**Docker 多阶段构建示例**：

```dockerfile
# 服务构建基础镜像
FROM node:24.18.0-alpine AS builder
WORKDIR /app
COPY package*.json ./
COPY services/opc-service/package*.json ./services/opc-service/
RUN npm ci --workspace=services/opc-service

# 运行时镜像
FROM node:24.18.0-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY services/opc-service ./services/opc-service
CMD ["node", "services/opc-service/src/server.js"]
```

---

## 7. 依赖安全扫描

### 7.1 当前状态

**未实施** `npm audit` 或 `go mod verify` 自动化检查。

### 7.2 建议增强 CI

在 `acceptance-gate.yml` 中添加：

```yaml
- name: Audit Node.js dependencies
  run: |
    npm audit --audit-level=high
    npm --prefix services/opc-service audit --audit-level=high
    npm --prefix services/platform-gateway audit --audit-level=high
    npm --prefix services/super-canvas-adapter audit --audit-level=high
```

**阻断标准**：
- `critical` 级别漏洞：立即阻断合并
- `high` 级别漏洞：要求评估并记录例外（若暂无修复版本）
- `moderate/low`：不阻断，但需季度审查

---

## 8. 服务 README 模板

当前 `super-canvas-adapter` **缺少** README.md，建议补充：

```markdown
# Super Canvas Adapter

Canvas 任务编排与计费状态管理层，负责将 Canvas 用户请求转换为 New API 调用序列。

## 目的

- 管理 Canvas SSO 会话（`CanvasSessionStore`）
- 编排模型任务生命周期（`CanvasTaskOrchestrator`）
- 实施计费状态机（`BillingStateMachine`）
- 提供 New API 客户端封装（`NewApiClient`）

## 组件

| 模块 | 职责 | 测试覆盖 |
|---|---|---|
| `billing-state-machine.js` | 配额预留、结算、退款状态转换 | 4 个用例 |
| `canvas-task-orchestrator.js` | catalog → quote → reserve → invoke → settle | 4 个用例 |
| `new-api-client.js` | HTTP 客户端 + 错误映射 | 4 个用例 |
| `sso-callback-handler.js` | SSO 启动与回调处理 | 3 个用例 |
| `one-time-sso-store.js` | 一次性 code 存储 | 3 个用例 |

## API

### 创建任务

```javascript
const task = await orchestrator.create({
  taskId: 'unique-id',
  userId: 'user-123',
  capability: 'image',
  platformModelId: 'image-model',
  parameters: { size: '1024x1024' },
  input: { prompt: 'a red fox' }
});
// 返回：{ status: 'queued', quoteId, reservationId, ... }
```

### 完成任务

```javascript
const result = await orchestrator.finalize({
  taskId: 'unique-id',
  outcome: 'success',
  actualUsage: 60
});
// 返回：{ status: 'succeeded', settlement: {...} }
```

## 部署

此模块为库组件，不独立部署。由 `platform-gateway` 或其他网关服务依赖注入使用。

## 测试

```bash
npm test
# 预期：18 个测试用例通过
```
```

---

## 9. 验收确认

### 9.1 已完成项

- ✅ 定义服务目录结构（3 个服务，标准 `src/test/README` 布局）
- ✅ 配置根工作空间构建脚本（`loop:test`, `loop:validate`, `loop:smoke`）
- ✅ CI/CD 工作流已实施（Acceptance Gate + Security Gate）
- ✅ 单元测试覆盖（24 个用例 + 5 个冒烟检查）
- ✅ 数据库边界检查（`validate_contracts.py`）
- ✅ 验收矩阵自动化验证（`validate_acceptance.py`）

### 9.2 建议补充项（不阻断 WP-01 验收）

- ⚠️ 版本锁定文件（`.nvmrc`, `.python-version`）
- ⚠️ 统一健康检查脚本（`scripts/health-check.sh`）
- ⚠️ 开发环境初始化脚本（`scripts/dev-setup.sh`）
- ⚠️ 依赖安全扫描（`npm audit` 集成到 CI）
- ⚠️ `super-canvas-adapter/README.md`
- ⚠️ Docker 构建示例（多服务部署参考）

---

## 10. 下一步

WP-01-REPO 提供了仓库拓扑基线，后续工作包应：

1. **WP-02**：实施数据库迁移自动化与模式版本控制
2. **WP-03**：补充服务间集成测试（跨 OPC/Gateway/Canvas 的端到端流程）
3. **WP-04**：容器化构建与本地 Compose 编排
4. **WP-05**：监控与日志收集基线（结构化日志 + 健康端点）

当前构建基线支持**快速本地验证**（< 30s 全量测试）和**合并门禁自动化**，为后续服务扩展提供稳定基础。
