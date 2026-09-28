# TapCanvas 与 new-api 整合方案

## 已确认边界

- new-api 是唯一登录、用户身份、管理员权限和账务中心。
- TapCanvas 使用自己的 PostgreSQL，仅保存项目、画布、素材、任务编排和运行状态。
- 入口使用 new-api 同一品牌下的 `canvas.<主域名>` 子域名。
- TapCanvas 自有积分、订阅和余额不作为最终扣费来源。
- 导航名称为“AI漫剧”，由 new-api 的 `HeaderNavModules.tapcanvas` 控制显示/隐藏。

## 登录链路

1. new-api 导航跳转到 TapCanvas `/auth/sso/start`。
2. TapCanvas 生成随机 `state`，用 HttpOnly Cookie 保存回跳地址和 state。
3. TapCanvas 跳转到 new-api `/api/user/auth/sso/authorize`。
4. new-api 通过 dashboard Bearer 或刷新 Cookie确认登录会话，创建 60 秒、单次消费的 `auth_flows` code，并回跳 TapCanvas。
5. TapCanvas 后端携带独立 `NEW_API_SSO_INTERNAL_TOKEN` 调用 new-api `/internal/v1/sso/exchange`。
6. TapCanvas 校验 code、state 和回跳地址，按 new-api `user_id` 创建/更新本地映射，再签发自己的 HttpOnly 会话 Cookie。

长期访问令牌不进入 URL；code 只允许 `audience=tapcanvas`，回跳地址通过 new-api 的 `TAPCANVAS_SSO_REDIRECT_URI` 精确 allowlist 校验。生产环境 new-api 必须设置 `SESSION_COOKIE_DOMAIN=.主域名`，否则跨子域名跳转不会携带登录 Cookie。

## 用户和管理员映射

TapCanvas `users.id` 使用 new-api 用户 ID 的字符串形式。SSO 交换时把 new-api `role >= 10` 映射为 TapCanvas `admin`，普通用户映射为 `user`；管理员界面和项目管理接口继续只认 `role=admin`。TapCanvas 不再提供独立管理员入口，管理员增删改统一在 new-api 完成，重新 SSO 时同步角色。

## 账务切换

目标合同固定为：

`quote -> reserve -> invoke -> settle/refund`

其中 quote、reserve、settle/refund 都以 new-api 用户 ID 和幂等 effect ID 为主键；TapCanvas 只保存任务和账务引用，不保存可消费余额。切换前必须完成：

- new-api 提供图片、视频、Agent、视觉分析统一的 quote/reserve/settle/refund API；
- TapCanvas 增加 server-to-server billing client、超时和重试策略；
- reserve 成功后才允许调用模型，invoke 失败必须 refund；
- settle 失败进入可恢复状态，不得回退为 TapCanvas 本地扣费；
- `TAPCANVAS_LOCAL_BILLING_ENABLED=false` 时本地积分路径必须拒绝执行，不能静默免费。

当前代码已完成 SSO 和导航，但媒体/Agent 生产路径仍有 TapCanvas 本地积分结算调用，因此尚未宣称计费切换完成；在上述端点未部署前应保持生产流量关闭。

## 部署参数

new-api：

```env
SESSION_COOKIE_DOMAIN=.example.com
TAPCANVAS_SSO_REDIRECT_URI=https://canvas.example.com/auth/sso/callback
TAPCANVAS_SSO_INTERNAL_TOKEN=<独立随机密钥>
```

TapCanvas API：

```env
NEW_API_PUBLIC_BASE_URL=https://api.example.com
NEW_API_INTERNAL_BASE_URL=http://new-api:3001
NEW_API_SSO_AUTHORIZE_URL=https://api.example.com/api/user/auth/sso/authorize
NEW_API_SSO_EXCHANGE_URL=http://new-api:3001/internal/v1/sso/exchange
NEW_API_SSO_INTERNAL_TOKEN=<与 new-api 相同的独立随机密钥>
```

反向代理只需把 `canvas.example.com` 的静态前端和 `/api`、`/auth` 等请求转到 TapCanvas API；不要暴露 TapCanvas bundled `apps/new-api` 作为第二账务中心。TapCanvas PostgreSQL 与 new-api 数据库保持独立。

## 验收顺序

1. new-api 后台开启“AI漫剧”，关闭后导航不出现。
2. 未登录访问 TapCanvas，能回到 new-api 登录并自动回到原页面。
3. 登录后刷新、重复使用 code、修改 state、修改 redirect URI 均被拒绝。
4. new-api 普通用户和管理员分别验证项目隔离及管理员接口。
5. 计费 API 完成 quote/reserve/invoke/settle/refund 集成测试后，再打开媒体和 Agent 生产入口。
