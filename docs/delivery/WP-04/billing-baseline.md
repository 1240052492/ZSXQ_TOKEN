# WP-04 Billing Baseline

状态：`in_progress`

`services/super-canvas-adapter/src/billing-state-machine.js` is a local
reference for the required business transitions:

- quote captures a model snapshot and immutable price version;
- reserve creates a task-level reservation;
- success charges actual usage and releases unused reservation;
- failed, cancelled and moderation-rejected tasks return the full reservation;
- reservation and settlement retries are idempotent; conflicting duplicate
  payloads and double finalization are rejected.

The component contains no wallet balance and does not persist a ledger. It is
not a substitute for New API wallet integration. The next implementation slice
will add New API quote/reservation/settlement client methods and persist task
references in `super_canvas`.

The current client/orchestrator slice is covered by
[`test-report.md`](./test-report.md).
