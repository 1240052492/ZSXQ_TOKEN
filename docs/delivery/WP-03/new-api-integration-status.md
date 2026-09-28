# New API 基座整合状态

## 已实现

- `services/platform-gateway` 提供统一入口 `/canvas` 和 `/canvas/login`。
- 未配置 `NEW_API_BASE_URL` 时，登录明确返回 `503 NEW_API_NOT_CONFIGURED`，不会回退到 LocalMiniDrama 本地账号。
- 配置 New API 后，入口跳转到 `/internal/v1/sso/authorize`，固定 `audience=canvas` 和回调地址。
- Canvas 的 SSO、模型目录、报价、预扣、代理、结算均通过 `services/super-canvas-adapter/src/new-api-client.js` 访问 New API 内部契约。

## 尚未完成

- 当前仓库没有 `QuantumNous/new-api` 上游源码、可运行容器或真实 endpoint/token。
- 因此尚未完成真实 New API 登录、统一用户表、钱包/充值/账本、模型主数据和代理调用的端到端联调。
- `vendor/LocalMiniDrama` 仍是独立 vendor 应用；其 SQLite、本地登录和供应商配置不能作为统一平台数据源。接入完成前只能作为画布 UI 参考或被反向代理的前端。

## 运行边界

```powershell
$env:NEW_API_BASE_URL = 'https://<new-api-host>'
$env:CANVAS_CALLBACK_URL = 'https://<canvas-host>/sso/callback'
npm start --prefix services/platform-gateway
```

验收必须提供真实 New API 地址、服务账号权限、回调域名和脱敏请求/响应证据；仅运行本仓库 mock 或 LocalMiniDrama 不得标记 M03/M06/M08/M11/M12 为通过。

## ��������ð��֤��

- /health ���� 200���� 
ewApiConfigured=false��
- /canvas/login ���� 503 NEW_API_NOT_CONFIGURED��������˵� LocalMiniDrama ���ص�¼��
- ��ʵ New API ��ת��δִ�У���Ϊ��ǰû�п��õ� New API endpoint��
