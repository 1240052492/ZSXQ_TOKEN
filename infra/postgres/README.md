# Local PostgreSQL isolation baseline

This directory defines the local-demo database boundary for `WP-02`.

The production target is one PostgreSQL cluster with three databases:

- `new_api`: owned and migrated by New API; wallet, users, model/channel and
  payment tables remain private to New API.
- `opc_core`: service registry, business-event intake, policy versions and
  cross-service audit index.
- `super_canvas`: canvas projects, tasks, nodes, asset references and
  read-only shares.

The SQL files here are standalone migrations. They do not create foreign keys
or SQL references across databases. Cross-service references are UUID/string
IDs exchanged through the internal contract in
`contracts/platform-integration.openapi.yaml`.

## Local usage

Run each migration while connected to its target database as an administrative
user, then apply `roles.sql` from the cluster admin connection. Passwords and
provider credentials are intentionally not stored in this repository.

```powershell
psql "$env:ZSXQ_NEW_API_ADMIN_DSN" -f infra/postgres/roles.sql
psql "$env:ZSXQ_OPC_CORE_DSN" -f infra/postgres/opc_core/001_init.sql
psql "$env:ZSXQ_SUPER_CANVAS_DSN" -f infra/postgres/super_canvas/001_init.sql
```

The DSN variables are local-only placeholders. No production migration has
been executed by this repository.
