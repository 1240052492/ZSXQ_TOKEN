# WP-01-ENV: 环境变量模板与配置管理

状态：`completed`  
负责人：Engineering Loop  
完成日期：2026-09-28

## 1. 环境变量盘点

基于当前代码库分析，识别出以下环境变量使用模式：

### 1.1 已使用的环境变量

| 变量名 | 服务 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `NODE_ENV` | opc-service | string | 否 | - | 运行环境标识；影响 Cookie Secure 属性 |
| `PORT` | opc-service | number | 否 | 8890 | OPC 服务监听端口 |
| `PORT` | platform-gateway | number | 否 | 8787 | Platform Gateway 监听端口 |
| `NEW_API_BASE_URL` | opc-service, platform-gateway | string | **是** | - | New API 服务基础 URL（需 HTTPS） |
| `OPC_PUBLIC_URL` | opc-service | string | **是** | - | OPC 服务公网访问地址（需 HTTPS） |
| `OPC_SSO_REDIRECT_URI` | opc-service | string | 否 | `${OPC_PUBLIC_URL}/sso/callback` | SSO 回调地址 |
| `OPC_SSO_INTERNAL_TOKEN` | opc-service | string | **是** | - | OPC 与 New API 内部服务认证令牌 |
| `CANVAS_APP_URL` | platform-gateway | string | 否 | - | Canvas 应用前端地址 |

### 1.2 待补充的环境变量

根据架构设计和 OPC 集成工作包，需要补充以下配置：

| 变量名 | 服务 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `DATABASE_URL` | new-api, opc-service, super-canvas-adapter | string | **是** | - | PostgreSQL 连接字符串（支持多库配置） |
| `NEW_API_DB_*` | new-api | string | **是** | - | New API 数据库连接配置组 |
| `OPC_DB_*` | opc-service | string | **是** | - | OPC 数据库连接配置组 |
| `CANVAS_DB_*` | super-canvas-adapter | string | **是** | - | Canvas 数据库连接配置组 |
| `SERVICE_TOKEN_SECRET` | all | string | **是** | - | 内部服务间认证签名密钥（64+ 字符） |
| `JWT_SECRET` | new-api | string | **是** | - | JWT 签名密钥（32+ 字符） |
| `JWT_EXPIRY` | new-api | string | 否 | 24h | JWT 过期时间 |
| `SESSION_SECRET` | opc-service, super-canvas-adapter | string | **是** | - | 会话签名密钥（32+ 字符） |
| `REDIS_URL` | new-api, opc-service | string | 否 | - | Redis 连接字符串（可选缓存层） |
| `S3_ENDPOINT` | super-canvas-adapter | string | 否 | - | 对象存储端点（MinIO/S3/COS） |
| `S3_BUCKET` | super-canvas-adapter | string | 否 | - | 对象存储桶名 |
| `S3_ACCESS_KEY` | super-canvas-adapter | string | 否 | - | 对象存储访问密钥 |
| `S3_SECRET_KEY` | super-canvas-adapter | string | 否 | - | 对象存储签名密钥 |
| `STORAGE_ROOT` | super-canvas-adapter | string | 否 | ./storage | 本地存储根目录（未配置对象存储时） |
| `LOG_LEVEL` | all | string | 否 | info | 日志级别（debug/info/warn/error） |
| `NEW_API_TIMEOUT_MS` | opc-service, super-canvas-adapter | number | 否 | 10000 | New API 请求超时（毫秒） |
| `COOKIE_MAX_AGE` | opc-service, super-canvas-adapter | number | 否 | 28800 | Cookie 最大生命周期（秒，默认 8 小时） |

## 2. 配置层次设计

```
┌─────────────────────────────────────────┐
│   环境变量（最高优先级）                 │
│   - 生产密钥                             │
│   - 部署特定配置                         │
│   - Docker secrets / K8s ConfigMap      │
└─────────────────────────────────────────┘
              ↓ 覆盖
┌─────────────────────────────────────────┐
│   .env.local（本地开发，git ignored）    │
│   - 开发者个人配置                       │
│   - 本地数据库密码                       │
│   - 调试开关                             │
└─────────────────────────────────────────┘
              ↓ 覆盖
┌─────────────────────────────────────────┐
│   .env（项目默认，仅用于示例）           │
│   - 从 .env.example 复制                 │
│   - 不提交到 git                         │
└─────────────────────────────────────────┘
              ↓ 加载
┌─────────────────────────────────────────┐
│   services/*/config.js（服务配置）       │
│   - 端口、超时、重试                     │
│   - 日志格式                             │
│   - 特性开关                             │
└─────────────────────────────────────────┘
```

### 配置加载流程

```mermaid
graph LR
    A[应用启动] --> B{读取 .env}
    B --> C[加载 process.env]
    C --> D[services/config.js]
    D --> E{必填项检查}
    E -->|缺失| F[抛出错误并退出]
    E -->|完整| G[初始化服务]
    G --> H[运行时动态覆盖]
```

## 3. 环境变量模板

### 3.1 完整 .env.example

```bash
# ============================================
# 环境与运行模式
# ============================================
NODE_ENV=development
LOG_LEVEL=info

# ============================================
# 数据库配置 - New API
# ============================================
# 方式1: 单一连接字符串（推荐生产环境）
NEW_API_DATABASE_URL=postgresql://new_api_runtime:CHANGEME@localhost:5432/new_api

# 方式2: 分离配置（开发环境友好）
NEW_API_DB_HOST=localhost
NEW_API_DB_PORT=5432
NEW_API_DB_NAME=new_api
NEW_API_DB_USER=new_api_runtime
NEW_API_DB_PASSWORD=CHANGEME
NEW_API_DB_SSL=false
NEW_API_DB_POOL_MIN=2
NEW_API_DB_POOL_MAX=10

# ============================================
# 数据库配置 - OPC
# ============================================
OPC_DATABASE_URL=postgresql://opc_runtime:CHANGEME@localhost:5432/opc_core

# 或分离配置
OPC_DB_HOST=localhost
OPC_DB_PORT=5432
OPC_DB_NAME=opc_core
OPC_DB_USER=opc_runtime
OPC_DB_PASSWORD=CHANGEME
OPC_DB_SSL=false
OPC_DB_POOL_MIN=2
OPC_DB_POOL_MAX=10

# ============================================
# 数据库配置 - Canvas
# ============================================
CANVAS_DATABASE_URL=postgresql://canvas_runtime:CHANGEME@localhost:5432/super_canvas

# 或分离配置
CANVAS_DB_HOST=localhost
CANVAS_DB_PORT=5432
CANVAS_DB_NAME=super_canvas
CANVAS_DB_USER=canvas_runtime
CANVAS_DB_PASSWORD=CHANGEME
CANVAS_DB_SSL=false
CANVAS_DB_POOL_MIN=2
CANVAS_DB_POOL_MAX=10

# ============================================
# Redis（可选）
# ============================================
# REDIS_URL=redis://localhost:6379/0
# REDIS_PASSWORD=
# REDIS_TLS=false

# ============================================
# 服务端口
# ============================================
NEW_API_PORT=3000
OPC_PORT=8890
PLATFORM_GATEWAY_PORT=8787
CANVAS_PORT=3002

# ============================================
# 服务公网地址（生产环境必填，需 HTTPS）
# ============================================
NEW_API_BASE_URL=https://token.example.com
OPC_PUBLIC_URL=https://opc.example.com
CANVAS_APP_URL=https://canvas.example.com

# 开发环境可使用 HTTP
# NEW_API_BASE_URL=http://localhost:3000
# OPC_PUBLIC_URL=http://localhost:8890
# CANVAS_APP_URL=http://localhost:3002

# ============================================
# 内部服务认证
# ============================================
# 服务间调用签名密钥（至少 64 字符，生产环境使用 openssl rand -base64 48）
SERVICE_TOKEN_SECRET=CHANGEME_AT_LEAST_64_CHARS_USE_CRYPTOGRAPHICALLY_SECURE_RANDOM

# OPC 与 New API 内部认证令牌（至少 32 字符）
OPC_SSO_INTERNAL_TOKEN=CHANGEME_AT_LEAST_32_CHARS_FOR_OPC_INTERNAL_AUTH

# ============================================
# JWT 配置
# ============================================
JWT_SECRET=CHANGEME_AT_LEAST_32_CHARS_FOR_JWT_SIGNING
JWT_EXPIRY=24h
JWT_ALGORITHM=HS256

# ============================================
# 会话配置
# ============================================
SESSION_SECRET=CHANGEME_AT_LEAST_32_CHARS_FOR_SESSION_SIGNING
COOKIE_MAX_AGE=28800
# COOKIE_DOMAIN=.example.com  # 子域名共享 Cookie 时设置

# ============================================
# SSO 配置
# ============================================
# OPC SSO 回调地址（通常自动生成，无需手动配置）
# OPC_SSO_REDIRECT_URI=${OPC_PUBLIC_URL}/sso/callback

# ============================================
# 对象存储（可选，未配置时使用本地存储）
# ============================================
# S3_ENDPOINT=https://s3.amazonaws.com
# S3_REGION=us-east-1
# S3_BUCKET=zsxq-canvas-assets
# S3_ACCESS_KEY=CHANGEME
# S3_SECRET_KEY=CHANGEME
# S3_USE_SSL=true

# 本地存储配置（对象存储未配置时生效）
STORAGE_ROOT=./storage
STORAGE_MAX_SIZE_MB=1024

# ============================================
# 超时与限流
# ============================================
NEW_API_TIMEOUT_MS=10000
OPC_REQUEST_TIMEOUT_MS=30000
CANVAS_TASK_TIMEOUT_MS=60000

# ============================================
# 特性开关（通常在数据库或后台管理）
# ============================================
# OPC_ENABLED=false  # OPC 默认关闭，通过 New API 后台管理
# CANVAS_DEBUG=false

# ============================================
# 监控与追踪
# ============================================
# SENTRY_DSN=
# SENTRY_ENVIRONMENT=development
# OTEL_EXPORTER_OTLP_ENDPOINT=
```

### 3.2 开发环境快速启动模板

```bash
# .env.local.example - 开发者复制到 .env.local 并修改
NODE_ENV=development
LOG_LEVEL=debug

# 本地数据库（无密码）
NEW_API_DATABASE_URL=postgresql://postgres@localhost:5432/new_api_dev
OPC_DATABASE_URL=postgresql://postgres@localhost:5432/opc_dev
CANVAS_DATABASE_URL=postgresql://postgres@localhost:5432/canvas_dev

# 本地服务地址
NEW_API_BASE_URL=http://localhost:3000
OPC_PUBLIC_URL=http://localhost:8890
CANVAS_APP_URL=http://localhost:3002

# 开发用固定密钥（不要用于生产）
SERVICE_TOKEN_SECRET=dev_service_token_secret_DO_NOT_USE_IN_PRODUCTION_MINIMUM_64_CHARS
OPC_SSO_INTERNAL_TOKEN=dev_opc_internal_token_32_chars
JWT_SECRET=dev_jwt_secret_32_chars_only
SESSION_SECRET=dev_session_secret_32_chars_ok

# 本地存储
STORAGE_ROOT=./dev-storage
```

## 4. 密钥管理策略

### 4.1 密钥分类与要求

| 密钥类型 | 最小长度 | 生成方式 | 轮换周期 | 存储方式 |
|----------|----------|----------|----------|----------|
| `SERVICE_TOKEN_SECRET` | 64 字符 | `openssl rand -base64 48` | 180 天 | 环境变量 / K8s Secret |
| `JWT_SECRET` | 32 字符 | `openssl rand -base64 24` | 90 天 | 环境变量 / K8s Secret |
| `SESSION_SECRET` | 32 字符 | `openssl rand -base64 24` | 90 天 | 环境变量 / K8s Secret |
| `OPC_SSO_INTERNAL_TOKEN` | 32 字符 | `openssl rand -base64 24` | 90 天 | 环境变量 / K8s Secret |
| `S3_SECRET_KEY` | 由云厂商决定 | 云控制台 | 年度审计 | 环境变量 / K8s Secret |
| 数据库密码 | 16+ 字符 | `openssl rand -base64 16` | 年度审计 | 环境变量 / K8s Secret |

### 4.2 密钥生成脚本

```bash
#!/bin/bash
# scripts/generate-secrets.sh

echo "生成新的密钥..."
echo ""
echo "SERVICE_TOKEN_SECRET=$(openssl rand -base64 48)"
echo "JWT_SECRET=$(openssl rand -base64 24)"
echo "SESSION_SECRET=$(openssl rand -base64 24)"
echo "OPC_SSO_INTERNAL_TOKEN=$(openssl rand -base64 24)"
echo "NEW_API_DB_PASSWORD=$(openssl rand -base64 16)"
echo "OPC_DB_PASSWORD=$(openssl rand -base64 16)"
echo "CANVAS_DB_PASSWORD=$(openssl rand -base64 16)"
echo ""
echo "⚠️  请将这些值复制到 .env.local 或环境变量配置中"
echo "⚠️  不要提交到 git 或共享到公开渠道"
```

### 4.3 环境隔离策略

| 环境 | 配置来源 | 密钥管理 | 访问控制 |
|------|----------|----------|----------|
| **开发环境** | `.env.local`（git ignored） | 本地文件，开发者自己生成 | 不限制 |
| **Lisa 服务器** | 环境变量 or Docker Compose secrets | 服务器文件系统（600 权限） | SSH 密钥 + sudo |
| **测试环境** | K8s ConfigMap + Secret | Kubernetes Secret（etcd 加密） | RBAC |
| **生产环境** | K8s Secret + Vault | HashiCorp Vault or 云 KMS | 最小权限 + 审计日志 |

### 4.4 密钥轮换流程

```mermaid
graph TD
    A[密钥到期提醒] --> B[生成新密钥]
    B --> C[更新环境变量]
    C --> D[重启服务]
    D --> E[验证服务正常]
    E --> F{验证通过?}
    F -->|是| G[销毁旧密钥]
    F -->|否| H[回滚到旧密钥]
    G --> I[记录轮换日志]
    H --> J[排查问题]
```

**JWT 密钥轮换特殊处理**：

JWT 签名密钥轮换会使所有现有 token 失效。生产环境建议：

1. 支持多密钥验证（`JWT_SECRET` 数组）
2. 新密钥签发，旧密钥仍可验证
3. 观察期（24-48h）后移除旧密钥

### 4.5 密钥泄露应急响应

1. **立即操作**：
   - 禁用泄露的密钥
   - 回滚到上一个已知安全的密钥
   - 强制用户重新登录（JWT 场景）

2. **后续措施**：
   - 审计日志，确定泄露范围
   - 生成新密钥并更新所有环境
   - 通知安全团队和相关人员

3. **预防措施**：
   - 禁止在代码、日志、错误堆栈中输出密钥
   - 使用 `.gitignore` 防止 `.env.local` 提交
   - Git pre-commit hook 扫描敏感信息

## 5. 配置验证脚本

### 5.1 验证脚本实现

```javascript
// scripts/validate-env.mjs
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(__dirname, '..');

// 环境变量定义
const ENV_SCHEMA = {
  // 服务配置
  NODE_ENV: { required: false, pattern: /^(development|production|test)$/ },
  LOG_LEVEL: { required: false, pattern: /^(debug|info|warn|error)$/ },
  
  // 数据库（至少需要一种配置方式）
  NEW_API_DATABASE_URL: { required: false, pattern: /^postgresql:\/\/.+/ },
  NEW_API_DB_HOST: { required: false },
  NEW_API_DB_PORT: { required: false, pattern: /^\d+$/ },
  NEW_API_DB_NAME: { required: false },
  NEW_API_DB_USER: { required: false },
  NEW_API_DB_PASSWORD: { required: false, minLength: 8 },
  
  OPC_DATABASE_URL: { required: false, pattern: /^postgresql:\/\/.+/ },
  CANVAS_DATABASE_URL: { required: false, pattern: /^postgresql:\/\/.+/ },
  
  // 服务地址
  NEW_API_BASE_URL: { required: true, pattern: /^https?:\/\/.+/ },
  OPC_PUBLIC_URL: { required: true, pattern: /^https?:\/\/.+/ },
  
  // 密钥
  SERVICE_TOKEN_SECRET: { required: true, minLength: 64 },
  JWT_SECRET: { required: true, minLength: 32 },
  SESSION_SECRET: { required: true, minLength: 32 },
  OPC_SSO_INTERNAL_TOKEN: { required: true, minLength: 32 },
  
  // 端口
  NEW_API_PORT: { required: false, pattern: /^\d+$/ },
  OPC_PORT: { required: false, pattern: /^\d+$/ },
  PLATFORM_GATEWAY_PORT: { required: false, pattern: /^\d+$/ },
};

const errors = [];
const warnings = [];

// 检查 .env 文件是否存在
const envPath = join(projectRoot, '.env');
if (!existsSync(envPath)) {
  warnings.push('.env 文件不存在，将使用系统环境变量');
}

// 验证必填项
for (const [key, spec] of Object.entries(ENV_SCHEMA)) {
  const value = process.env[key];
  
  if (spec.required && !value) {
    errors.push(`缺少必填环境变量: ${key}`);
    continue;
  }
  
  if (!value) continue;
  
  // 验证格式
  if (spec.pattern && !spec.pattern.test(value)) {
    errors.push(`${key} 格式不正确，期望匹配: ${spec.pattern}`);
  }
  
  // 验证最小长度
  if (spec.minLength && value.length < spec.minLength) {
    errors.push(`${key} 长度不足，最少需要 ${spec.minLength} 字符`);
  }
  
  // 检查是否使用示例值
  if (value.includes('CHANGEME') || value.includes('example.com')) {
    warnings.push(`${key} 仍在使用示例值，请替换为实际配置`);
  }
}

// 检查数据库配置完整性
const hasNewApiDbUrl = Boolean(process.env.NEW_API_DATABASE_URL);
const hasNewApiDbParts = Boolean(
  process.env.NEW_API_DB_HOST &&
  process.env.NEW_API_DB_NAME &&
  process.env.NEW_API_DB_USER
);

if (!hasNewApiDbUrl && !hasNewApiDbParts) {
  errors.push('New API 数据库配置不完整：需要 NEW_API_DATABASE_URL 或完整的 DB_* 配置组');
}

// 生产环境额外检查
if (process.env.NODE_ENV === 'production') {
  if (process.env.NEW_API_BASE_URL?.startsWith('http://')) {
    errors.push('生产环境必须使用 HTTPS');
  }
  
  if (process.env.LOG_LEVEL === 'debug') {
    warnings.push('生产环境不建议使用 debug 日志级别');
  }
  
  // 检查默认开发密钥
  const devSecrets = ['dev_', 'DO_NOT_USE_IN_PRODUCTION'];
  for (const [key, value] of Object.entries(process.env)) {
    if (key.includes('SECRET') || key.includes('PASSWORD') || key.includes('TOKEN')) {
      if (devSecrets.some(dev => value?.includes(dev))) {
        errors.push(`${key} 使用了开发环境默认值，生产环境禁止使用`);
      }
    }
  }
}

// 输出结果
console.log('='.repeat(60));
console.log('环境变量验证结果');
console.log('='.repeat(60));

if (warnings.length > 0) {
  console.log('\n⚠️  警告:');
  warnings.forEach(w => console.log(`  - ${w}`));
}

if (errors.length > 0) {
  console.log('\n❌ 错误:');
  errors.forEach(e => console.log(`  - ${e}`));
  console.log('\n请修复以上错误后重试');
  process.exit(1);
}

console.log('\n✅ 环境变量验证通过');
console.log('='.repeat(60));
```

### 5.2 使用方式

```bash
# 验证当前环境变量
node scripts/validate-env.mjs

# 在服务启动前自动验证
npm run validate-env && npm start

# CI/CD 集成
npm run validate-env || exit 1
```

### 5.3 集成到 package.json

```json
{
  "scripts": {
    "validate-env": "node scripts/validate-env.mjs",
    "prestart": "npm run validate-env",
    "start": "node services/*/server.js"
  }
}
```

## 6. 服务配置加载示例

### 6.1 统一配置加载器

```javascript
// services/lib/config-loader.js
export function loadConfig(serviceName, schema) {
  const config = {};
  const missing = [];
  
  for (const [key, spec] of Object.entries(schema)) {
    const envKey = spec.env || key;
    const value = process.env[envKey];
    
    if (spec.required && !value) {
      missing.push(envKey);
      continue;
    }
    
    config[key] = value ?? spec.default;
  }
  
  if (missing.length > 0) {
    throw new Error(
      `${serviceName} missing required environment variables: ${missing.join(', ')}`
    );
  }
  
  return config;
}
```

### 6.2 服务配置示例

```javascript
// services/opc-service/config.js
import { loadConfig } from '../lib/config-loader.js';

export const config = loadConfig('opc-service', {
  port: {
    env: 'OPC_PORT',
    default: 8890,
    required: false,
  },
  newApiBaseUrl: {
    env: 'NEW_API_BASE_URL',
    required: true,
  },
  publicUrl: {
    env: 'OPC_PUBLIC_URL',
    required: true,
  },
  internalToken: {
    env: 'OPC_SSO_INTERNAL_TOKEN',
    required: true,
  },
  databaseUrl: {
    env: 'OPC_DATABASE_URL',
    required: true,
  },
  logLevel: {
    env: 'LOG_LEVEL',
    default: 'info',
    required: false,
  },
});
```

## 7. 部署环境配置示例

### 7.1 Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  new-api:
    image: new-api:latest
    environment:
      - NODE_ENV=production
      - NEW_API_DATABASE_URL=${NEW_API_DATABASE_URL}
      - JWT_SECRET=${JWT_SECRET}
      - SERVICE_TOKEN_SECRET=${SERVICE_TOKEN_SECRET}
    env_file:
      - .env.production
    secrets:
      - new_api_db_password
      - jwt_secret
    ports:
      - "3000:3000"
  
  opc-service:
    image: opc-service:latest
    environment:
      - NODE_ENV=production
      - OPC_DATABASE_URL=${OPC_DATABASE_URL}
      - NEW_API_BASE_URL=https://token.example.com
      - OPC_PUBLIC_URL=https://opc.example.com
    env_file:
      - .env.production
    secrets:
      - opc_db_password
      - opc_internal_token
    ports:
      - "8890:8890"
    depends_on:
      - new-api

secrets:
  new_api_db_password:
    external: true
  jwt_secret:
    external: true
  opc_db_password:
    external: true
  opc_internal_token:
    external: true
```

### 7.2 Kubernetes ConfigMap + Secret

```yaml
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  NEW_API_BASE_URL: "https://token.example.com"
  OPC_PUBLIC_URL: "https://opc.example.com"
  NEW_API_PORT: "3000"
  OPC_PORT: "8890"

---
# k8s/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
stringData:
  NEW_API_DATABASE_URL: "postgresql://user:pass@postgres:5432/new_api"
  OPC_DATABASE_URL: "postgresql://user:pass@postgres:5432/opc_core"
  JWT_SECRET: "<base64-encoded-secret>"
  SERVICE_TOKEN_SECRET: "<base64-encoded-secret>"
  SESSION_SECRET: "<base64-encoded-secret>"
  OPC_SSO_INTERNAL_TOKEN: "<base64-encoded-token>"

---
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: opc-service
spec:
  template:
    spec:
      containers:
      - name: opc
        image: opc-service:latest
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: app-secrets
```

## 8. 安全检查清单

- [ ] 所有 `.env*` 文件已添加到 `.gitignore`
- [ ] 生产密钥长度符合最小要求
- [ ] 生产环境不使用开发默认值
- [ ] 密钥不出现在代码、日志或错误消息中
- [ ] 数据库连接使用 SSL/TLS（生产环境）
- [ ] 服务间通信使用内部认证令牌
- [ ] JWT 密钥与会话密钥分离
- [ ] 对象存储密钥与数据库密钥分离
- [ ] 密钥轮换计划已建立
- [ ] 密钥泄露应急预案已准备

## 9. 下一步工作

1. **WP-01-DB**：数据库迁移脚本与模式管理
2. **WP-02-CONTRACT**：服务间接口契约与验证
3. **WP-03-SSO**：完整 SSO 流程与会话管理实现
4. **WP-04-BILLING**：计费、预扣、结算流程实现

## 附录 A：环境变量速查表

```bash
# 快速复制到 .env.local
cp .env.example .env.local

# 生成所有密钥
./scripts/generate-secrets.sh >> .env.local

# 验证配置
npm run validate-env

# 启动所有服务
npm start
```

## 附录 B：故障排查

**问题：服务启动失败，提示缺少环境变量**
- 检查 `.env` 或 `.env.local` 是否存在
- 运行 `npm run validate-env` 查看具体缺失项

**问题：数据库连接失败**
- 确认 `DATABASE_URL` 格式正确
- 检查数据库是否已启动：`pg_isready -h localhost -p 5432`
- 验证用户名密码是否正确

**问题：SSO 跳转失败**
- 确认 `NEW_API_BASE_URL` 和 `OPC_PUBLIC_URL` 可互相访问
- 检查 `OPC_SSO_INTERNAL_TOKEN` 两端是否一致
- 查看浏览器 Cookie 是否被阻止（需 HTTPS 或 localhost）

**问题：生产环境密钥泄露**
- 立即执行 `./scripts/generate-secrets.sh` 生成新密钥
- 更新所有服务的环境变量
- 滚动重启服务
- 检查访问日志，确定泄露范围
