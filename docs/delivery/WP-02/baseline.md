# WP-02 Database and Service Contract Baseline

状态：`in_progress` (M2 complete, M3 pending)

## Milestones

### M1: PostgreSQL 容器化部署 ✅ COMPLETE
- 基础设施代码 (docker-compose, Dockerfile)
- 初始化脚本和配置
- 健康检查验证

### M2: 数据库架构迁移 ✅ COMPLETE (2026-09-29)
- wallet/ledger/payment 从 new_api 迁移到 opc_core
- 数据库隔离验证
- 权限边界测试
- **Deliverable:** M2-completion-report.md

### M3: 运行时用户和权限 (NEXT)
- 生产角色定义
- 权限授予脚本
- 连接字符串模式

### M4: 生产就绪配置
- 备份策略
- 监控集成
- 故障恢复测试

## Implemented artifacts

- `contracts/platform-integration.openapi.yaml`
- `infra/postgres/roles.sql`
- `infra/postgres/opc_core/001_init.sql`
- `infra/postgres/super_canvas/001_init.sql`
- `infra/postgres/migrations/002_migrate_payment_schemas.sql` ✅ NEW
- `scripts/validate_contracts.py`
- `infra/postgres/docker-compose.yml` and executable role/bootstrap scripts

## Verified locally

```text
WP-02 contract and database boundary checks passed
Acceptance matrix valid: 25 items; gate_mode=baseline
```

The static validator confirms:

- SSO, model catalog, quote, reservation, proxy invocation and settlement paths are present.
- Idempotency keys and price-version fields are required by the contract.
- `super_canvas` does not define wallet or ledger tables. ✅ VERIFIED in M2
- `opc_core` defines business-event intake.
- Migrations contain no cross-database foreign keys. ✅ VERIFIED in M2

## Runtime verification ✅ COMPLETE (M2)

PostgreSQL cluster is running with three isolated databases:
- `super_canvas`: canvas_projects, platform_user_refs
- `opc_core`: business_events, wallet_accounts, ledger_entries, payment_transactions
- `new_api`: empty (reserved)

### Permission boundaries verified:
- Canvas runtime user CANNOT access opc_core tables (permission denied)
- OPC runtime user CANNOT access super_canvas tables (permission denied)
- Cross-database isolation enforced at PostgreSQL level
- Migration idempotency confirmed

See: `docs/delivery/WP-02/M2-completion-report.md` for full test evidence.

## Not yet verified

- Production runtime role definitions (M3)
- Permission grant automation for each service (M3)
- Connection pooling and service authentication patterns (M3)
- Runtime service request signing (blocked by WP-00 contracts)
- New API implementation of the contract (blocked by WP-00)
- LocalMiniDrama replacement of SQLite/local provider paths

This package is not complete until M3 runtime users are defined and M4 production configuration is ready.
