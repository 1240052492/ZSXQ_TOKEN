# Platform Contracts

`platform-integration.openapi.yaml` is the first internal contract for the
New API control plane and the future `super_canvas` service.

## Rules

- The contract is internal and does not expose provider credentials.
- `super_canvas` sends business/task events and reservation references; it
  never writes New API wallet balances or ledger rows.
- Every reservation, proxy invocation and settlement request carries an
  `Idempotency-Key`.
- Model calls carry a model snapshot and published price version. A failed
  compatibility check must fail the task rather than silently select another
  model or price.
- The local Demo may use placeholder `http://new-api.internal`; production
  DNS, authentication and transport security are separate deployment work.

## Current status

The document is a design contract for `WP-02`. It is not an implemented API.
The next implementation slice must add request/response contract tests and
service-account permission tests before wiring LocalMiniDrama to it.
