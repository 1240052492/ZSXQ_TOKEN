# WP-01: 跨服务OpenAPI契约定义

## 1. 服务调用拓扑

```
┌─────────────────┐
│   浏览器客户端   │
└────────┬────────┘
         │ HTTPS (跨域)
         │
    ┌────▼────────────────────────────────┐
    │        New API (主服务)              │
    │  - 用户认证/授权                     │
    │  - SSO授权码签发                     │
    │  - 模型目录管理                      │
    │  - 钱包/预扣/结算                    │
    │  - 上游模型调用                      │
    └──┬──────────────────────────────┬───┘
       │ 内部API (私有网络)            │
       │ Authorization: Bearer         │
       │ X-Service-Name: <service>     │
       │                               │
  ┌────▼─────────┐            ┌───────▼──────────┐
  │ Canvas适配器  │            │   OPC服务         │
  │ (super-canvas│            │  (opc-service)   │
  │  -adapter)   │            │                  │
  │              │            │  - AO编排引擎     │
  │ - 任务编排   │            │  - 工作流执行     │
  │ - 流式代理   │            │  - 素材管理       │
  └──────────────┘            └──────────────────┘
```

**调用方向**：
- Canvas/OPC → New API: SSO授权码兑换、模型目录查询、余额查询、预扣/结算/退款、受控模型代理
- New API → 上游Provider: 实际模型调用（Canvas/OPC不直接访问）
- 浏览器 → New API → Canvas/OPC: SSO跳转流程

**安全边界**：
- 内部API仅监听私有网络接口或通过反向代理ACL限制
- Canvas/OPC不得访问New API数据库
- 浏览器不得持有SERVICE_TOKEN
- 上游Provider凭证仅存储在New API

## 2. 服务间认证机制

### 2.1 SERVICE_TOKEN生成与管理

**生成**：
```bash
# 使用加密安全的随机数生成器
SERVICE_TOKEN=$(openssl rand -base64 48)
```

**存储**：
- New API环境变量: `CANVAS_SERVICE_TOKEN`, `OPC_SERVICE_TOKEN`
- Canvas/OPC环境变量: `NEW_API_SERVICE_TOKEN`
- 仅通过环境变量注入，禁止硬编码或提交到版本控制
- 生产环境使用密钥管理服务（Vault/AWS Secrets Manager/K8s Secrets）

**验证**：
```javascript
// New API端验证伪代码
function verifyServiceToken(req) {
  const authHeader = req.headers['authorization'];
  const serviceName = req.headers['x-service-name'];
  
  if (!authHeader?.startsWith('Bearer ')) {
    throw new UnauthorizedError('Missing bearer token');
  }
  
  const token = authHeader.slice(7);
  const expectedToken = getServiceToken(serviceName); // 从配置读取
  
  if (!crypto.timingSafeEqual(
    Buffer.from(token),
    Buffer.from(expectedToken)
  )) {
    throw new UnauthorizedError('Invalid service token');
  }
  
  return serviceName;
}
```

### 2.2 请求头规范

所有内部API调用必须包含以下头部：

```http
Authorization: Bearer <SERVICE_TOKEN>
X-Service-Name: super-canvas-adapter|opc-service
X-Request-ID: <uuid-v4>
Content-Type: application/json
```

**幂等性保证的mutation操作额外需要**：
```http
Idempotency-Key: <uuid-v4或业务唯一标识>
```

### 2.3 请求日志与审计

记录字段：
- `timestamp`: ISO 8601格式
- `request_id`: X-Request-ID
- `service_name`: X-Service-Name
- `endpoint`: 请求路径
- `method`: HTTP方法
- `user_id`: 业务用户ID（如适用）
- `status_code`: HTTP状态码
- `duration_ms`: 请求耗时
- `error_code`: 业务错误码（如失败）

敏感字段脱敏：
- SERVICE_TOKEN: 不记录
- 授权码: 仅记录哈希
- 钱包余额: 仅在调试模式记录

## 3. 核心接口契约

完整OpenAPI 3.0规范见: `/api/contracts/new-api-internal.openapi.yaml`

### 3.1 SSO授权码接口

**用途**：Canvas/OPC通过一次性授权码换取用户会话

#### 签发授权码（浏览器直接调用）
```http
GET /api/user/auth/{service}/authorize?redirect_uri=<uri>&state=<state>
Cookie: refresh_token=<...>
```

**响应**：302重定向到`redirect_uri`并携带：
```
{redirect_uri}?code=<auth_code>&state=<state>
```

**约束**：
- `redirect_uri`必须预注册白名单
- `code`有效期60秒，单次消费
- `state`由调用方生成并验证（防CSRF）
- 需要New API有效登录会话

#### 兑换授权码（内部服务调用）
```http
POST /internal/v1/sso/exchange
Authorization: Bearer <SERVICE_TOKEN>
X-Service-Name: super-canvas-adapter
X-Request-ID: <uuid>
Content-Type: application/json

{
  "code": "auth_abc123...",
  "audience": "canvas",
  "state": "csrf_xyz789..."
}
```

**成功响应** (200):
```json
{
  "user_id": 12345,
  "session_subject": "sess_a1b2c3d4",
  "user_status": "active"
}
```

**失败场景**：
- 401: 授权码无效/过期/已消费
- 403: 用户已禁用或服务未启用
- 400: 参数缺失或格式错误

### 3.2 模型目录接口

**用途**：获取当前用户可用的模型列表

```http
GET /internal/v1/models/catalog?capability=text&user_id=12345
Authorization: Bearer <SERVICE_TOKEN>
X-Service-Name: opc-service
X-Request-ID: <uuid>
```

**成功响应** (200):
```json
{
  "items": [
    {
      "id": "gpt-4-turbo",
      "name": "GPT-4 Turbo",
      "capabilities": ["text"],
      "price_per_1k_tokens": "0.03",
      "price_version": "2024-03",
      "provider_label": "OpenAI",
      "parameter_profiles": ["default", "creative", "precise"]
    },
    {
      "id": "claude-3-opus",
      "name": "Claude 3 Opus",
      "capabilities": ["text"],
      "price_per_1k_tokens": "0.015",
      "price_version": "2024-03",
      "provider_label": "Anthropic"
    }
  ]
}
```

**过滤规则**：
- 仅返回`enabled=true`的模型
- 仅返回用户/组有权限的模型
- 仅返回满足`capability`的模型
- 不返回Provider API Key或内部渠道URL

### 3.3 钱包余额接口

**用途**：查询用户可用余额和冻结金额

```http
GET /internal/v1/wallet/balance?user_id=12345
Authorization: Bearer <SERVICE_TOKEN>
X-Service-Name: super-canvas-adapter
X-Request-ID: <uuid>
```

**成功响应** (200):
```json
{
  "balance": "98.50",
  "currency": "CNY",
  "reserved": "1.50"
}
```

**说明**：
- `balance`: 可用余额（不含冻结）
- `reserved`: 当前预扣冻结金额
- 余额不足时仍返回200，由预扣接口返回409

### 3.4 预扣接口

**用途**：在模型调用前冻结预估费用

```http
POST /internal/v1/reservations
Authorization: Bearer <SERVICE_TOKEN>
X-Service-Name: opc-service
X-Request-ID: <uuid>
Idempotency-Key: <uuid>
Content-Type: application/json

{
  "user_id": 12345,
  "task_id": "canvas_task_abc123",
  "model_id": "gpt-4-turbo",
  "estimated_tokens": 2000,
  "source": "canvas",
  "run_id": "run_xyz789",
  "step_id": "step_001"
}
```

**成功响应** (200):
```json
{
  "reservation_id": "rsv_def456",
  "reserved_quota": "0.06",
  "status": "reserved",
  "expires_at": "2024-03-15T10:30:00Z"
}
```

**失败场景**：
- 409: 余额不足 (`INSUFFICIENT_BALANCE`)
- 404: 模型不存在或已停用 (`MODEL_NOT_FOUND`)
- 403: 用户无权使用该模型 (`MODEL_NOT_AUTHORIZED`)

**约束**：
- 预扣有效期15分钟
- 超时未结算自动释放
- 幂等性保证：相同`Idempotency-Key`返回相同`reservation_id`

### 3.5 受控模型代理接口

**用途**：通过New API代理调用上游模型

```http
POST /internal/v1/model-proxy/invoke
Authorization: Bearer <SERVICE_TOKEN>
X-Service-Name: super-canvas-adapter
X-Request-ID: <uuid>
Idempotency-Key: <uuid>
Content-Type: application/json

{
  "reservation_id": "rsv_def456",
  "user_id": 12345,
  "task_id": "canvas_task_abc123",
  "model_id": "gpt-4-turbo",
  "parameters": {
    "messages": [
      {"role": "user", "content": "Hello"}
    ],
    "temperature": 0.7,
    "max_tokens": 500
  },
  "source": "canvas"
}
```

**成功响应** (200):
```json
{
  "request_id": "req_ghi789",
  "task_id": "canvas_task_abc123",
  "status": "succeeded",
  "result": {
    "content": "Hello! How can I help you?",
    "usage": {
      "prompt_tokens": 10,
      "completion_tokens": 8,
      "total_tokens": 18
    }
  }
}
```

**异步响应**（图像/视频模型）：
```json
{
  "request_id": "req_ghi789",
  "task_id": "canvas_task_abc123",
  "status": "queued"
}
```

**失败场景**：
- 404: 预扣ID不存在或已过期 (`RESERVATION_EXPIRED`)
- 400: 参数验证失败 (`INVALID_PARAMETERS`)
- 503: 上游服务不可用 (`UPSTREAM_UNAVAILABLE`)

### 3.6 结算接口

**用途**：使用实际用量结算并退还差额

```http
POST /internal/v1/settlements
Authorization: Bearer <SERVICE_TOKEN>
X-Service-Name: opc-service
X-Request-ID: <uuid>
Idempotency-Key: <uuid>
Content-Type: application/json

{
  "reservation_id": "rsv_def456",
  "actual_tokens": 18,
  "actual_usage": "0.00054"
}
```

**成功响应** (200):
```json
{
  "reservation_id": "rsv_def456",
  "status": "settled",
  "charged_usage": "0.00054",
  "refunded_usage": "0.05946",
  "transaction_id": "txn_jkl012"
}
```

**说明**：
- `charged_usage`: 实际扣费金额
- `refunded_usage`: 退还金额（预扣 - 实际）
- 幂等性保证：重复调用返回相同结果，不重复结算

## 4. 错误码标准

### 4.1 HTTP状态码映射

| HTTP状态码 | 含义 | 使用场景 |
|-----------|------|---------|
| 200 | 成功 | 请求成功处理 |
| 400 | 客户端错误 | 参数缺失、格式错误 |
| 401 | 未授权 | SERVICE_TOKEN无效或缺失 |
| 403 | 禁止访问 | 用户已禁用、服务未启用 |
| 404 | 资源不存在 | 模型/用户/预扣不存在 |
| 409 | 冲突 | 余额不足、幂等性冲突 |
| 429 | 速率限制 | 超出服务调用频率 |
| 500 | 服务器错误 | 内部逻辑错误 |
| 503 | 服务不可用 | 上游服务故障、维护中 |

### 4.2 业务错误码清单

| 错误码 | HTTP状态 | 说明 | 重试策略 |
|--------|---------|------|---------|
| `INVALID_REQUEST` | 400 | 请求参数缺失或格式错误 | 不重试，修正参数 |
| `UNAUTHORIZED` | 401 | SERVICE_TOKEN无效 | 不重试，检查配置 |
| `SERVICE_DISABLED` | 403 | 目标服务未启用 | 不重试，检查后台开关 |
| `USER_SUSPENDED` | 403 | 用户账号已禁用 | 不重试，提示用户 |
| `MODEL_NOT_FOUND` | 404 | 模型不存在或已停用 | 不重试，刷新目录 |
| `MODEL_NOT_AUTHORIZED` | 403 | 用户无权使用该模型 | 不重试，检查权限 |
| `USER_NOT_FOUND` | 404 | 用户不存在 | 不重试，检查user_id |
| `INSUFFICIENT_BALANCE` | 409 | 用户余额不足 | 不重试，提示充值 |
| `RESERVATION_NOT_FOUND` | 404 | 预扣ID不存在 | 不重试，检查流程 |
| `RESERVATION_EXPIRED` | 404 | 预扣已过期 | 可重试预扣+调用 |
| `SSO_CODE_INVALID` | 401 | 授权码无效/过期/已用 | 不重试，重新授权 |
| `SSO_STATE_MISMATCH` | 400 | CSRF state不匹配 | 不重试，检查实现 |
| `UPSTREAM_UNAVAILABLE` | 503 | 上游Provider不可用 | 指数退避重试 |
| `UPSTREAM_TIMEOUT` | 504 | 上游调用超时 | 指数退避重试 |
| `RATE_LIMIT_EXCEEDED` | 429 | 超出调用频率限制 | 等待后重试 |
| `IDEMPOTENCY_CONFLICT` | 409 | 幂等性键冲突 | 不重试，检查业务逻辑 |

**错误响应格式**：
```json
{
  "error": {
    "code": "INSUFFICIENT_BALANCE",
    "message": "User balance insufficient for reservation",
    "details": {
      "user_id": 12345,
      "required": "0.06",
      "available": "0.02"
    }
  }
}
```

## 5. 幂等性设计

### 5.1 幂等性保证范围

**需要幂等性保证的操作**：
- POST /internal/v1/reservations（预扣）
- POST /internal/v1/model-proxy/invoke（模型调用）
- POST /internal/v1/settlements（结算）

**不需要幂等性的操作**：
- GET /internal/v1/models/catalog（查询）
- GET /internal/v1/wallet/balance（查询）
- POST /internal/v1/sso/exchange（授权码本身单次消费）

### 5.2 实现机制

**客户端生成`Idempotency-Key`**：
```javascript
// Canvas/OPC生成幂等性键
const idempotencyKey = `${taskId}_reserve_${Date.now()}_${crypto.randomUUID()}`;
```

**服务端处理**：
```javascript
async function handleIdempotentRequest(key, operation) {
  // 1. 检查缓存
  const cached = await redis.get(`idempotency:${key}`);
  if (cached) {
    return JSON.parse(cached);
  }
  
  // 2. 获取分布式锁
  const lock = await redis.set(`idempotency:lock:${key}`, '1', 'EX', 10, 'NX');
  if (!lock) {
    // 另一个请求正在处理，等待后重试
    await sleep(100);
    return handleIdempotentRequest(key, operation);
  }
  
  try {
    // 3. 执行业务逻辑
    const result = await operation();
    
    // 4. 缓存结果（15分钟）
    await redis.setex(`idempotency:${key}`, 900, JSON.stringify(result));
    
    return result;
  } finally {
    await redis.del(`idempotency:lock:${key}`);
  }
}
```

**约束**：
- 幂等性键最小长度16字符
- 缓存有效期15分钟
- 相同键返回完全相同的响应（包括HTTP状态码）
- 不同操作类型使用不同的键（避免预扣和结算冲突）

### 5.3 幂等性测试场景

1. **网络超时重试**：客户端未收到响应，重发相同请求
2. **并发重复请求**：前端重复点击，短时间内发送多个相同请求
3. **Worker重启**：异步任务处理中断，重启后重新处理
4. **分布式部署**：多个New API实例收到相同幂等性键

## 6. 契约测试框架

### 6.1 测试工具选型

推荐使用**Pact**进行契约测试：
- 消费者驱动的契约（Consumer-Driven Contracts）
- 支持HTTP/JSON契约定义
- 独立于具体实现的stub验证

### 6.2 契约测试示例

#### Canvas消费者契约（Pact定义）
```javascript
// services/super-canvas-adapter/test/contract/new-api.pact.test.js
const { PactV3, MatchersV3 } = require('@pact-foundation/pact');
const { NewApiClient } = require('../../src/new-api-client');

describe('New API SSO Exchange Contract', () => {
  const provider = new PactV3({
    consumer: 'super-canvas-adapter',
    provider: 'new-api-internal',
  });

  it('exchanges valid code for user session', async () => {
    await provider
      .given('user 12345 has valid auth code')
      .uponReceiving('SSO code exchange request')
      .withRequest({
        method: 'POST',
        path: '/internal/v1/sso/exchange',
        headers: {
          'Authorization': MatchersV3.like('Bearer token123'),
          'X-Service-Name': 'super-canvas-adapter',
          'X-Request-ID': MatchersV3.uuid(),
          'Content-Type': 'application/json',
        },
        body: {
          code: MatchersV3.string('auth_code_abc'),
          audience: 'canvas',
          state: MatchersV3.string('state_xyz'),
        },
      })
      .willRespondWith({
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: {
          user_id: MatchersV3.integer(12345),
          session_subject: MatchersV3.string('sess_abc'),
          user_status: MatchersV3.regex('active', /active|suspended|disabled/),
        },
      });

    await provider.executeTest(async (mockServer) => {
      const client = new NewApiClient({
        baseUrl: mockServer.url,
        serviceToken: 'token123',
      });
      
      const result = await client.exchangeCanvasCode({
        code: 'auth_code_abc',
        state: 'state_xyz',
      });
      
      expect(result.userId).toBe(12345);
      expect(result.sessionSubject).toBe('sess_abc');
    });
  });

  it('rejects expired code', async () => {
    await provider
      .given('auth code has expired')
      .uponReceiving('SSO exchange with expired code')
      .withRequest({
        method: 'POST',
        path: '/internal/v1/sso/exchange',
        body: {
          code: 'expired_code',
          audience: 'canvas',
          state: 'state_xyz',
        },
      })
      .willRespondWith({
        status: 401,
        body: {
          error: {
            code: 'SSO_CODE_INVALID',
            message: MatchersV3.string('Authorization code expired'),
          },
        },
      });

    await provider.executeTest(async (mockServer) => {
      const client = new NewApiClient({
        baseUrl: mockServer.url,
        serviceToken: 'token123',
      });
      
      await expect(
        client.exchangeCanvasCode({
          code: 'expired_code',
          state: 'state_xyz',
        })
      ).rejects.toThrow(/expired/i);
    });
  });
});
```

#### 提供者验证（New API端）
```javascript
// vendor/new-api/test/contract/pact-verification.test.js
const { Verifier } = require('@pact-foundation/pact');
const path = require('path');

describe('New API Internal Contract Verification', () => {
  it('validates contracts from consumers', async () => {
    const verifier = new Verifier({
      providerBaseUrl: 'http://localhost:3100',
      pactUrls: [
        path.resolve(__dirname, '../../pacts/super-canvas-adapter-new-api-internal.json'),
        path.resolve(__dirname, '../../pacts/opc-service-new-api-internal.json'),
      ],
      providerVersion: process.env.GIT_COMMIT,
      providerVersionTags: ['dev'],
      stateHandlers: {
        'user 12345 has valid auth code': async () => {
          await seedAuthCode({ userId: 12345, code: 'auth_code_abc' });
        },
        'auth code has expired': async () => {
          await seedExpiredAuthCode({ code: 'expired_code' });
        },
      },
    });

    await verifier.verifyProvider();
  });
});
```

### 6.3 Stub服务部署

**开发环境Stub**：
```bash
# 启动New API契约stub（Canvas/OPC开发时使用）
pact-stub-server \
  --file ./api/contracts/new-api-internal.openapi.yaml \
  --port 3100
```

**CI/CD集成**：
```yaml
# .github/workflows/contract-test.yml
name: Contract Tests
on: [pull_request]
jobs:
  consumer-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Canvas consumer tests
        run: npm test -- services/super-canvas-adapter/test/contract
      - name: Publish pacts
        run: |
          npx pact-broker publish \
            --pact-dir ./pacts \
            --consumer-app-version ${{ github.sha }} \
            --tag ${{ github.ref_name }}

  provider-verification:
    runs-on: ubuntu-latest
    needs: consumer-tests
    steps:
      - uses: actions/checkout@v3
      - name: Start New API
        run: docker-compose up -d new-api
      - name: Verify contracts
        run: npm test -- vendor/new-api/test/contract/pact-verification.test.js
```

## 7. 安全注意事项

### 7.1 密钥轮换策略

- SERVICE_TOKEN每90天轮换一次
- 轮换流程：
  1. 生成新TOKEN并配置到New API
  2. New API同时接受新旧TOKEN（24小时过渡期）
  3. 更新Canvas/OPC配置为新TOKEN
  4. 验证新TOKEN工作正常
  5. New API移除旧TOKEN

### 7.2 网络隔离

- 内部API仅监听私有网络接口（如`10.0.0.0/8`）
- 或使用反向代理ACL限制来源IP
- 禁止将内部API暴露到公网

### 7.3 请求验证

- 验证`X-Service-Name`与TOKEN匹配
- 验证`user_id`存在且状态正常
- 验证`model_id`在目录中且用户有权限
- 所有金额使用decimal类型（避免浮点精度问题）

### 7.4 审计日志

所有内部API调用记录审计日志：
- 调用方服务
- 用户ID
- 操作类型（SSO/预扣/结算等）
- 请求参数摘要
- 响应状态
- 失败原因

日志保留期：至少180天

## 8. 性能与容量规划

### 8.1 性能目标

| 接口 | P99延迟 | QPS |
|------|--------|-----|
| SSO Exchange | <200ms | 100 |
| Model Catalog | <50ms | 500 |
| Wallet Balance | <30ms | 1000 |
| Reservation | <100ms | 200 |
| Model Invoke | <30s | 100 |
| Settlement | <100ms | 200 |

### 8.2 缓存策略

- 模型目录：Redis缓存，TTL 5分钟
- 用户权限：Redis缓存，TTL 1分钟
- 幂等性记录：Redis缓存，TTL 15分钟
- 余额查询：不缓存（实时）

### 8.3 超时配置

- 内部API调用超时：10秒
- 上游模型调用超时：30秒（文本）、5分钟（图像/视频）
- 预扣超时：15分钟自动释放

## 9. 参考文档

- OpenAPI规范: `/api/contracts/new-api-internal.openapi.yaml`
- Canvas客户端实现: `/services/super-canvas-adapter/src/new-api-client.js`
- OPC集成工作包: `/docs/development/opc-integration-work-packages.md`
- 账务流程设计: `/docs/delivery/WP-04/billing-baseline.md`
