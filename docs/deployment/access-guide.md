# ZSXQ Token 项目测试访问指南

## 当前部署状态

### 已部署服务

#### PostgreSQL 数据库（运行中）
- **位置**: `infra/postgres/`
- **访问地址**: `localhost:55432`
- **状态**: ✅ Healthy（运行 2+ 小时）
- **凭据**:
  - 管理员用户: `postgres`
  - 密码: 通过环境变量 `ZSXQ_PG_ADMIN_PASSWORD` 配置
  - 默认数据库: `postgres`

#### 数据库架构（已验收 M05）
根据 M05 验收证据，已完成三库三账号隔离：

1. **super_wallet** - New API 钱包与账号数据库
   - 数据库账号: `super_wallet_app`
   - 权限: 完全独立，无法访问其他库

2. **opc_core** - 运营核心数据库（共享数据）
   - 数据库账号: `opc_core_app`
   - 存储: 模型目录、价格版本、渠道配置

3. **super_canvas** - 画布业务数据库
   - 数据库账号: `canvas_app`
   - 权限: **只读** 访问 `super_wallet` 的用户和余额表
   - 完全隔离: 无法写入钱包数据

**验收证据**: `docs/development/evidence/M05-database-isolation.md`

### 未部署服务

以下服务的 Docker Compose 配置已就绪但**尚未启动**：

#### TapCanvas 完整技术栈（`vendor/TapCanvas/docker-compose.yml`）
- **web**: 前端 SPA（端口 5175）
- **api**: Hono API 服务（端口 8788）
- **new-api**: New API 服务（端口 4455）
- **agents-bridge**: AI 代理桥接服务（端口 8799）
- **postgres**: TapCanvas 自带的 PostgreSQL（端口 5432）
- **redis**: Redis 缓存（端口 6379）
- **media-worker**: 媒体处理微服务（gRPC 9090）
- **workflow-runtime-worker**: 工作流运行时
- **credit-finalizer-worker**: 计费结算后台
- **async-image-worker**: 异步图片处理

#### 其他可选服务
- **vendor/agency-orchestrator**: Orca 编排服务
- **vendor/new-api**: 独立的 New API 部署

## 启动测试环境

### 方案 1: 完整 TapCanvas 技术栈（推荐）

```bash
cd /e/ZSXQ_TOKEN/vendor/TapCanvas

# 1. 准备环境变量文件
cp apps/hono-api/.env.example apps/hono-api/.env
# 编辑 .env 填入必需的配置（数据库连接、密钥等）

# 2. 启动所有服务
docker compose up -d

# 3. 查看服务状态
docker compose ps

# 4. 查看日志
docker compose logs -f api
docker compose logs -f web
docker compose logs -f new-api
```

**访问地址**（启动后）：
- Web UI: http://localhost:5175
- API: http://localhost:8788
- New API: http://localhost:4455
- New API Dashboard: http://localhost:4455/dashboard

### 方案 2: 最小化测试环境

如果只需要测试数据库隔离（M05），可以只使用已运行的 PostgreSQL：

```bash
# 连接到已运行的 PostgreSQL
psql -h localhost -p 55432 -U postgres

# 验证三库三账号
\l                                    # 列出所有数据库
\du                                   # 列出所有角色
\c super_wallet                       # 切换到钱包库
\dt                                   # 查看表结构
```

### 方案 3: 仅启动核心服务

如果资源受限，可以只启动必要服务：

```bash
cd /e/ZSXQ_TOKEN/vendor/TapCanvas

# 只启动 postgres、redis、new-api、api、web
docker compose up -d postgres redis new-api api web

# 等待服务就绪
docker compose logs -f api
```

## 环境变量配置清单

在启动 TapCanvas 服务前，需要在 `vendor/TapCanvas/apps/hono-api/.env` 配置：

### 必需配置
```bash
# PostgreSQL（复用已运行的实例或使用 compose 自带的）
POSTGRES_USER=tapcanvas
POSTGRES_PASSWORD=<your-password>
POSTGRES_DB=tapcanvas

# New API 数据库（应指向 super_wallet）
NEW_API_POSTGRES_DB=super_wallet

# 密钥（务必生成强随机值）
NEW_API_INTERNAL_TOKEN=<random-secret>
NEW_API_SSO_INTERNAL_TOKEN=<random-secret>
NEW_API_SESSION_SECRET=<random-secret>
NEW_API_CRYPTO_SECRET=<random-secret>

# New API 管理员
NEW_API_ROOT_USERNAME=admin
NEW_API_ROOT_PASSWORD=<strong-password>
```

### 可选配置
```bash
# 对象存储（本地测试可跳过）
VITE_OBJECT_STORAGE_PROVIDER=tos
VITE_TOS_PUBLIC_BASE_URL=<your-tos-url>

# AI 服务（本地测试可跳过）
AGENTS_API_KEY=<your-key>
```

## 验收测试路径

### M05: 三库三账号隔离
```bash
# 1. 连接数据库
psql -h localhost -p 55432 -U postgres

# 2. 验证数据库存在
\l

# 3. 验证角色权限
\du

# 4. 测试 canvas_app 只读权限
\c super_canvas
SET ROLE canvas_app;
SELECT * FROM super_wallet.users LIMIT 1;  -- 应成功（只读）
INSERT INTO super_wallet.users (...);       -- 应失败（无写权限）
```

### M03: 统一注册登录
```bash
# 启动 new-api 后访问
curl http://localhost:4455/api/status

# 访问管理面板
open http://localhost:4455/dashboard

# 登录测试
# 用户名: admin
# 密码: <NEW_API_ROOT_PASSWORD>
```

### M02: 域名与路由
目前本地测试使用 localhost，生产部署需要配置：
- `token.yourdomain.com` → New API (4455)
- `canvas.yourdomain.com` → Web UI (5175)
- 反向代理配置 HTTPS 和证书

## 故障排查

### PostgreSQL 连接失败
```bash
# 检查服务状态
docker ps | grep postgres

# 检查日志
docker logs postgres-postgres-1

# 验证端口
netstat -an | grep 55432
```

### TapCanvas 服务启动失败
```bash
# 查看具体服务日志
docker compose logs <service-name>

# 常见问题：
# 1. 环境变量未配置 → 检查 .env 文件
# 2. 端口冲突 → 修改 docker-compose.yml 中的端口映射
# 3. 依赖服务未就绪 → 等待 healthcheck 通过
```

### 数据库迁移失败
```bash
# 手动运行迁移
cd /e/ZSXQ_TOKEN/vendor/TapCanvas/apps/hono-api
pnpm db:update:local
```

## 下一步工作

根据验收矩阵 `docs/acceptance/matrix.json`，需要完成：

1. **P0 优先级**（阻断生产放行）:
   - M01: 固定上游 commit 和许可证审查
   - M03: 统一注册登录（依赖 New API 启动）
   - M04: 一次性 SSO
   - M06: 统一钱包与充值
   - M07: 预扣结算退款
   - ... 等其他 P0 项

2. **部署验证**:
   - 启动完整 TapCanvas 技术栈
   - 验证 Web UI 可访问
   - 验证用户注册登录流程
   - 验证 SSO 授权码兑换

3. **端到端测试**:
   - E2E-01: 正常画布任务
   - E2E-02: 失败与退款
   - E2E-03: 渠道故障
   - E2E-04: 价格版本冻结
   - E2E-05: 分享删除审核

## 当前可测试功能

✅ **已就绪**:
- PostgreSQL 数据库访问（localhost:55432）
- 数据库架构验证（M05 已通过）
- SQL 迁移脚本验证

❌ **需要启动服务后测试**:
- Web UI 访问
- 用户注册登录
- API 调用
- SSO 流程
- 画布功能
- 钱包充值

---

**最后更新**: 2026-09-29  
**当前分支**: `loop/init-framework-baseline`  
**验收状态**: M05 已通过，其余 24 项 planned
