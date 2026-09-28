# WP-04 Test Report

Date: 2026-09-22 Asia/Shanghai
Status: `in_progress` (runtime integration verified; billing contract remains fail-closed)

## Evidence

| Layer | Result | Evidence |
|---|---|---|
| Data/state | PASS | `billing-state-machine.test.js`: quote snapshot, reservation, settlement, refund and idempotency state |
| Functional | PASS | 17 Node tests across billing, New API client, SSO and task orchestration |
| Simulated data flow | PASS | `canvas-task-orchestrator.test.js`: catalog filter -> quote -> reserve -> invoke -> settle/refund |
| Smoke/static | PASS | `python scripts/validate_contracts.py`; `python scripts/validate_acceptance.py`; `git diff --check` |
| New API adapter | PASS | `node --test test/new-api-client.test.js test/canvas-task-orchestrator.test.js` (8/8) |
| TapCanvas focused | PARTIAL | Auth/cookies, chat billing, pricing: 24/25 passed; one existing CRLF source-string assertion failed |
| Browser smoke | PASS | Playwright found `AI漫剧`, href `/auth/sso/start`, click reached new-api without request failures |

## Scenarios covered

- Eligible model creates a task and freezes `price_version`.
- Model absent from the filtered catalog is rejected before quote/reserve.
- Proxy failure triggers failed settlement with zero actual usage.
- Success charges actual usage and returns unused reservation.
- Failed/cancelled/moderation-rejected outcomes return the reservation.
- Repeated idempotency keys return the original result; conflicting payloads reject.
- SSO client sends service authorization, `audience=canvas`, and idempotency headers where required.

## Not yet proven / blocked

- Real New API quote/reserve/invoke/settle/refund endpoints and wallet ledger integration. The current new-api checkout has SSO but does not yet expose these `/internal/v1/*` billing endpoints; TapCanvas therefore remains fail-closed when `TAPCANVAS_LOCAL_BILLING_ENABLED=false`.
- Real PostgreSQL role permissions and task persistence.
- Full TapCanvas Web/API suites are not green in this checkout: API tests reference missing repository paths (`deploy.sh`, `/workspace/apps/agents-cli`, `docker-compose.yml`) and Web full-suite exceeded the 120s verification window.
- Provider invocation and actual usage reporting against a sandbox model.
