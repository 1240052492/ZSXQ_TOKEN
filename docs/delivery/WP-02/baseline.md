# WP-02 Database and Service Contract Baseline

状态：`in_progress`

## Implemented artifacts

- `contracts/platform-integration.openapi.yaml`
- `infra/postgres/roles.sql`
- `infra/postgres/opc_core/001_init.sql`
- `infra/postgres/super_canvas/001_init.sql`
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
- `super_canvas` does not define wallet or ledger tables.
- `opc_core` defines business-event intake.
- Migrations contain no cross-database foreign keys.

## Runtime verification attempt

The local Docker smoke test was attempted with a temporary environment-only
admin password. The PostgreSQL image could not be pulled because the Docker
daemon proxy `172.26.128.1:7898` refused the connection. No database container
was started and no production or external database was touched.

## Not yet verified

- PostgreSQL role creation and grants against a real local cluster.
- Migration up/down or rollback behavior.
- Runtime service authentication and request signing.
- New API implementation of the contract.
- LocalMiniDrama replacement of SQLite/local provider paths.

This package is not complete until a local PostgreSQL instance executes the
migrations and permission tests prove that canvas cannot write wallet data.
