# WP-02 Database and Service Contract Baseline

状态：`in_progress`

## Implemented artifacts

- `contracts/platform-integration.openapi.yaml`
- `infra/postgres/roles.sql`
- `infra/postgres/opc_core/001_init.sql`
- `infra/postgres/super_canvas/001_init.sql`
- `scripts/validate_contracts.py`

## Verified locally

```text
WP-02 contract and database boundary checks passed
Acceptance matrix valid: 25 items; gate_mode=baseline
```

The static validator confirms:

- SSO, model catalog, quote, reservation, proxy invocation and settlement paths are present.
- Idempotency keys and price-version fields are required by the contract.
- `super_canvas` does not define wallet or ledger tables.
- `opc_core` defines business-event intake.
- Migrations contain no cross-database foreign keys.

## Not yet verified

- PostgreSQL role creation and grants against a real local cluster.
- Migration up/down or rollback behavior.
- Runtime service authentication and request signing.
- New API implementation of the contract.
- LocalMiniDrama replacement of SQLite/local provider paths.

This package is not complete until a local PostgreSQL instance executes the
migrations and permission tests prove that canvas cannot write wallet data.
