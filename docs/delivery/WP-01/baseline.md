# WP-01 Local Demo Baseline

状态：`in_progress`

## Frozen source inputs

- `vendor/new-api`: `9310231b3c27fea933e939b46cf26e0ce67192e3`
- `vendor/LocalMiniDrama`: `adaecf71a38277126fbe1e5e0d79664300f855c1`
- 源码通过 GitHub commit archive 导入；`vendor/` 不提交到本仓库。

## Environment

| 工具 | 结果 |
|---|---|
| Go | `go1.27.0 windows/amd64` |
| Node | `v24.18.0` |
| npm | `11.16.0` |
| pnpm | `10.28.2` |

## Executed checks

| 项目 | 命令 | 结果 |
|---|---|---|
| LocalMiniDrama backend dependencies | `npm ci` in `vendor/LocalMiniDrama/backend-node` | PASS; 174 packages installed |
| LocalMiniDrama database | `npm run migrate` | PASS; migrations completed against local SQLite |
| LocalMiniDrama frontend dependencies | `npm ci` in `vendor/LocalMiniDrama/frontweb` | PASS; 92 packages installed |
| LocalMiniDrama frontend build | `npm run build` in `vendor/LocalMiniDrama/frontweb` | PASS; Vite production build completed |
| New API backend build | `go build` in `vendor/new-api` | BLOCKED; embedded `web/dist` is absent |
| New API full test | `go test ./...` | INCONCLUSIVE/TIMEOUT after 180s; no completion result |

## Demo start commands

```powershell
cd vendor/LocalMiniDrama/backend-node
npm run migrate
npm start

# In another terminal
cd vendor/LocalMiniDrama/frontweb
npm run dev
```

LocalMiniDrama's current demo ports are backend `5679` and frontend `3013`/Vite default as configured by the upstream project. It still uses local SQLite, local storage and its upstream AI configuration; this is a baseline only and is not the integrated platform path.

## Next package

`WP-02` has started with [`contracts/platform-integration.openapi.yaml`](../../contracts/platform-integration.openapi.yaml), covering SSO, model catalog, quote, reservation, proxy invocation, usage, settlement and refund. Do not make LocalMiniDrama's local wallet/provider paths the platform contract.
