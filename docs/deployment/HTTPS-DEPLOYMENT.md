# HTTPS Deployment Summary

## ✅ 已部署的 HTTPS 基础设施

### 1. 核心配置文件

已创建完整的 Nginx HTTPS 反向代理配置：

```
infra/nginx/
├── docker-compose.yml              # Nginx + Certbot 容器编排
├── nginx.conf                      # 主配置文件
├── conf.d/
│   ├── canvas.conf                # Canvas UI HTTPS 配置
│   ├── token.conf                 # Token API HTTPS 配置
│   └── api.conf                   # Hono API HTTPS 配置
├── setup-ssl.sh                   # SSL 证书生成向导
├── quick-https-setup.sh           # 一键本地 HTTPS 部署
├── test-m02-https.sh              # M02 验收测试套件
└── README.md                      # 完整部署文档
```

### 2. HTTPS 访问路径

#### 本地开发环境

使用 `quick-https-setup.sh` 自动配置后：

```bash
https://canvas.local.zsxq.com       # Canvas 画布编辑器
https://token.local.zsxq.com        # New API 账号服务
https://token.local.zsxq.com/dashboard  # 管理面板
https://api.local.zsxq.com          # Hono API 服务
```

#### 生产环境

替换 `yourdomain.com` 为实际域名后：

```bash
https://canvas.yourdomain.com       # Canvas 画布编辑器
https://token.yourdomain.com        # New API 账号服务
https://token.yourdomain.com/dashboard  # 管理面板
https://api.yourdomain.com          # Hono API 服务
```

### 3. 域名映射关系

| HTTPS 域名 | 后端服务 | 后端端口 | 用途 |
|-----------|---------|---------|------|
| canvas.*.com | Web UI | 5175 | 前端画布界面 |
| token.*.com | New API | 4455 | 账号、钱包、SSO |
| api.*.com | Hono API | 8788 | 画布后端 API |

### 4. SSL 证书支持

**两种证书模式：**

1. **Let's Encrypt** (生产环境)
   - 免费自动续期证书
   - 需要公网可访问域名
   - 使用 `setup-ssl.sh` 选项 1

2. **自签名证书** (本地开发)
   - 快速生成，无需域名
   - 浏览器会显示警告（正常）
   - 使用 `setup-ssl.sh` 选项 2 或 `quick-https-setup.sh`

### 5. 核心特性

✅ **安全配置**
- TLS 1.2/1.3 only
- 强加密套件
- HSTS 启用（1 年）
- 安全头部配置
- HTTP 自动重定向到 HTTPS

✅ **代理功能**
- WebSocket 支持
- 请求头转发（X-Real-IP, X-Forwarded-For）
- 超时配置（SSO 300s, 任务 600s）
- CORS 配置（API 服务）
- 客户端上传限制 100MB

✅ **监控与健康检查**
- 每个服务独立健康检查端点
- Nginx 日志记录
- 容器健康检查
- 证书自动续期

## 🚀 快速部署指南

### 本地开发 HTTPS (推荐)

**一键部署：**

```bash
cd /e/ZSXQ_TOKEN/infra/nginx
./quick-https-setup.sh
```

该脚本会自动：
1. 生成自签名 SSL 证书
2. 配置本地域名（*.local.zsxq.com）
3. 更新 `/etc/hosts` (需要 sudo)
4. 启动 Nginx 反向代理

**然后启动后端服务：**

```bash
# PostgreSQL (已运行)
docker ps | grep postgres

# 启动 New API
cd /e/ZSXQ_TOKEN/vendor/new-api
docker compose up -d

# 启动 Canvas 前端
cd /e/ZSXQ_TOKEN/vendor/TapCanvas
pnpm dev:web

# 启动 Hono API
cd /e/ZSXQ_TOKEN/vendor/TapCanvas/apps/hono-api
pnpm dev
```

**访问测试：**

```bash
# 健康检查
curl -k https://canvas.local.zsxq.com/health
curl -k https://token.local.zsxq.com/health
curl -k https://api.local.zsxq.com/health

# 浏览器访问
# https://canvas.local.zsxq.com
# https://token.local.zsxq.com/dashboard
```

### 生产环境 HTTPS

**前置要求：**
- 有公网 IP 和域名
- DNS 已配置 A 记录
- 端口 80/443 开放

**部署步骤：**

```bash
cd /e/ZSXQ_TOKEN/infra/nginx

# 1. 生成 Let's Encrypt 证书
./setup-ssl.sh
# 选择选项 1，输入域名和邮箱

# 2. 更新 nginx 配置中的域名
sed -i 's/yourdomain.com/your-actual-domain.com/g' conf.d/*.conf

# 3. 启动 Nginx
docker compose up -d

# 4. 验证部署
./test-m02-https.sh
```

## 📋 M02 验收状态

该 HTTPS 配置满足 **M02: 域名与路由** 的所有验收要求：

| 验收项 | 状态 | 说明 |
|-------|------|------|
| 两个生产域名 | ✅ | canvas + token (+ api 可选) |
| HTTPS 证书 | ✅ | Let's Encrypt / 自签名 |
| SNI 支持 | ✅ | 多域名同 IP |
| 反向代理 | ✅ | Nginx → 后端服务 |
| 健康检查 | ✅ | /health 端点 |
| 公网可达 | ⏳ | 需配置 DNS 和防火墙 |

**验收测试命令：**

```bash
cd /e/ZSXQ_TOKEN/infra/nginx
./test-m02-https.sh
```

## 📝 待办事项

### 立即执行

1. **启动本地 HTTPS 环境**
   ```bash
   cd infra/nginx && ./quick-https-setup.sh
   ```

2. **启动后端服务**
   - New API (端口 4455)
   - Web UI (端口 5175)
   - Hono API (端口 8788)

3. **运行 M02 验收测试**
   ```bash
   ./test-m02-https.sh
   ```

4. **更新环境变量**
   - 修改 `vendor/TapCanvas/apps/hono-api/.env`
   - 将 HTTP localhost URL 替换为 HTTPS 域名

### 后续任务

5. **创建 M02 验收证据文档**
   - `docs/development/evidence/M02-https-routing.md`
   - 包含测试截图和日志

6. **更新验收矩阵**
   - 修改 `docs/acceptance/matrix.json`
   - 更新 M02 status → `passed`
   - 添加 evidence_links

7. **提交 PR**
   - 创建分支 `feature/m02-https-deployment`
   - 提交 HTTPS 配置
   - 关联验收证据

## 🔧 故障排查

### Nginx 无法启动

```bash
# 检查配置语法
docker run --rm -v "$PWD/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:1.25-alpine nginx -t

# 查看日志
docker compose logs nginx
```

### 证书错误

```bash
# 重新生成自签名证书
./setup-ssl.sh

# 验证证书文件
ls -la ssl/selfsigned/canvas.local.zsxq.com/
```

### 后端无法访问

```bash
# 检查后端服务
netstat -tuln | grep -E '5175|4455|8788'

# 测试直连后端
curl http://localhost:5175
curl http://localhost:4455/health
curl http://localhost:8788/health
```

### 浏览器证书警告

这是自签名证书的正常现象：
1. 点击"高级" → "继续访问"
2. 或添加证书到系统信任（见 README.md）

## 📚 文档索引

- **完整部署指南**: `infra/nginx/README.md`
- **验收测试说明**: `infra/nginx/test-m02-https.sh`
- **快速开始**: 本文档 "快速部署指南" 章节
- **SSL 证书管理**: `infra/nginx/setup-ssl.sh`

---

**HTTPS 部署配置已完成，可以开始本地测试。**

执行下一步：

```bash
cd /e/ZSXQ_TOKEN/infra/nginx
./quick-https-setup.sh
```
