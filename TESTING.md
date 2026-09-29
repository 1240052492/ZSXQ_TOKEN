# 测试访问指南

本文档提供 ZSXQ Token 项目的测试访问路径和快速启动指南。

## 快速开始

### 一键启动

```bash
# 从项目根目录执行
./docs/deployment/quick-start.sh
```

该脚本会：
1. 检查 Docker 环境
2. 启动/验证 PostgreSQL
3. 引导配置 TapCanvas 环境变量
4. 提供启动模式选择
5. 输出所有服务的访问地址

### 手动启动

#### 1. 启动 PostgreSQL（必需）

```bash
cd infra/postgres

# 设置管理员密码
export ZSXQ_PG_ADMIN_PASSWORD='your-strong-password'

# 启动数据库
docker compose up -d

# 检查状态
docker compose ps
```

#### 2. 启动 TapCanvas 服务（可选）

```bash
cd vendor/TapCanvas

# 准备配置文件
cp apps/hono-api/.env.example apps/hono-api/.env
# 编辑 .env 填入必需配置

# 完整启动（所有服务）
docker compose up -d

# 或仅启动核心服务
docker compose up -d postgres redis new-api api web
```

## 访问地址

### 当前运行的服务

✅ **PostgreSQL 数据库**
- 地址: `localhost:55432`
- 用户: `postgres`
- 密码: `$ZSXQ_PG_ADMIN_PASSWORD`
- 状态: 运行中 (Healthy)
- 连接: `psql -h localhost -p 55432 -U postgres`

### TapCanvas 服务（需要启动）

启动后可访问：

🌐 **Web UI**
- URL: http://localhost:5175
- 说明: TapCanvas 前端界面
- 功能: 画布编辑器、工作流设计

🔌 **Hono API**
- URL: http://localhost:8788
- 健康检查: http://localhost:8788/health/version
- 说明: TapCanvas 业务 API

💰 **New API (统一账号与钱包)**
- URL: http://localhost:4455
- 管理面板: http://localhost:4455/dashboard
- 默认账号: `admin` / 见 `.env` 配置
- 说明: 统一注册登录和钱包服务

🤖 **Agents Bridge**
- URL: http://localhost:8799
- 健康检查: http://localhost:8799/health
- 说明: AI 代理桥接服务

📦 **Redis**
- URL: `localhost:6379`
- 说明: 缓存和队列服务

## 验收测试路径

### M05: 数据库隔离 ✅ 已通过

```bash
# 完整验证脚本
cd docs/deployment
bash run-m05-verification.sh

# 或手动测试
psql -h localhost -p 55432 -U postgres << SQL
-- 验证数据库存在
\l

-- 验证角色
\du

-- 测试 canvas_app 只读权限
\c super_canvas
SET ROLE canvas_app;
SELECT * FROM super_wallet.users LIMIT 1;  -- 应成功
INSERT INTO super_wallet.users (username) VALUES ('hack');  -- 应失败
SQL
```

详细验证指南: `docs/deployment/database-verification.md`

### M03: 统一注册登录 (需要启动 New API)

```bash
# 1. 启动 New API
cd vendor/TapCanvas
docker compose up -d new-api

# 2. 检查服务状态
curl http://localhost:4455/api/status

# 3. 访问管理面板
open http://localhost:4455/dashboard

# 4. 登录测试
# 用户名: admin
# 密码: 见 apps/hono-api/.env 中的 NEW_API_ROOT_PASSWORD
```

### M04: 一次性 SSO (需要启动完整服务)

```bash
# 启动完整技术栈
cd vendor/TapCanvas
docker compose up -d

# 测试 SSO 流程
# 1. 访问 Web UI: http://localhost:5175
# 2. 点击登录
# 3. 应跳转到 New API 授权页面
# 4. 授权后应自动返回 Canvas 并登录成功
```

### E2E-01: 完整画布任务 (需要启动完整服务)

```bash
# 启动完整技术栈
cd vendor/TapCanvas
docker compose up -d

# 等待所有服务就绪
docker compose ps

# 访问 Web UI
open http://localhost:5175

# 手动测试流程:
# 1. 注册/登录账号
# 2. 充值余额
# 3. 创建画布工作流
# 4. 添加 AI 节点（文本/图像生成）
# 5. 执行任务
# 6. 验证扣款和结果保存
```

## 常用命令

### 查看服务状态

```bash
# PostgreSQL
cd infra/postgres
docker compose ps

# TapCanvas 服务
cd vendor/TapCanvas
docker compose ps
```

### 查看日志

```bash
# PostgreSQL
cd infra/postgres
docker compose logs -f

# TapCanvas API
cd vendor/TapCanvas
docker compose logs -f api

# TapCanvas Web
docker compose logs -f web

# New API
docker compose logs -f new-api

# 所有服务
docker compose logs -f
```

### 停止服务

```bash
# 停止 TapCanvas
cd vendor/TapCanvas
docker compose down

# 停止 PostgreSQL
cd infra/postgres
docker compose down

# 停止所有容器
docker stop $(docker ps -q)
```

### 重启服务

```bash
# 重启特定服务
cd vendor/TapCanvas
docker compose restart api
docker compose restart web

# 完全重建
docker compose down
docker compose up -d --build
```

### 数据库操作

```bash
# 连接数据库
export PGPASSWORD="${ZSXQ_PG_ADMIN_PASSWORD}"
psql -h localhost -p 55432 -U postgres

# 备份数据库
pg_dump -h localhost -p 55432 -U postgres -Fc super_wallet > backup_wallet.dump
pg_dump -h localhost -p 55432 -U postgres -Fc opc_core > backup_core.dump
pg_dump -h localhost -p 55432 -U postgres -Fc super_canvas > backup_canvas.dump

# 恢复数据库
pg_restore -h localhost -p 55432 -U postgres -d super_wallet backup_wallet.dump

# 执行迁移
cd vendor/TapCanvas/apps/hono-api
pnpm db:update:local
```

## 故障排查

### PostgreSQL 启动失败

```bash
# 检查环境变量
echo $ZSXQ_PG_ADMIN_PASSWORD

# 检查端口占用
netstat -an | grep 55432

# 查看日志
cd infra/postgres
docker compose logs

# 重新启动
docker compose down -v
docker compose up -d
```

### TapCanvas 服务启动失败

```bash
# 检查配置文件
ls -la vendor/TapCanvas/apps/hono-api/.env

# 检查依赖服务
cd vendor/TapCanvas
docker compose ps postgres redis

# 查看具体服务日志
docker compose logs api
docker compose logs new-api

# 重建服务
docker compose down
docker compose build api
docker compose up -d
```

### 无法连接数据库

```bash
# 测试连接
psql -h localhost -p 55432 -U postgres -c "SELECT 1"

# 检查容器网络
docker network ls
docker network inspect postgres_default

# 检查防火墙
# Windows: 允许 Docker Desktop 通过防火墙
# Linux: sudo ufw allow 55432
```

### 前端无法访问 API

```bash
# 检查 API 状态
curl http://localhost:8788/health/version

# 检查容器网络
docker network inspect tapcanvas_default

# 检查环境变量
cd vendor/TapCanvas
grep VITE_API_BASE apps/web/.env.production
```

## 下一步

完成基础环境搭建后，继续完成其他验收项：

1. **M01**: 固定上游 commit 和许可证审查
2. **M03**: 统一注册登录（依赖 New API）
3. **M04**: 一次性 SSO 授权码
4. **M06**: 统一钱包与充值
5. **M07**: 预扣结算退款流程

查看完整验收矩阵: `docs/acceptance/matrix.json`

## 相关文档

- [完整访问指南](docs/deployment/access-guide.md)
- [数据库验证指南](docs/deployment/database-verification.md)
- [快速启动脚本](docs/deployment/quick-start.sh)
- [验收矩阵](docs/acceptance/matrix.json)
- [工作包清单](docs/development/work-packages.md)

---

**最后更新**: 2026-09-29  
**当前分支**: `loop/init-framework-baseline`  
**PostgreSQL 状态**: ✅ 运行中  
**TapCanvas 状态**: ⏸ 未启动（配置就绪）
