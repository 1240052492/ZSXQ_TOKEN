# WP-04 Runtime Smoke Test Report

Date: 2026-09-23

## Scope

The integration now runs new-api on `127.0.0.1:3001`, TapCanvas API on `127.0.0.1:8788`, and the built Web preview on `127.0.0.1:5175`. The browser smoke test verifies the real new-api navigation click and TapCanvas SSO start redirect. No paid generation is enabled while the new-api billing contract is absent.

## Commands and results

| Check | Command | Result |
| --- | --- | --- |
| Unit tests | `npm test` in `services/super-canvas-adapter` | PASS, 18/18 |
| Contract boundary | `python scripts/validate_contracts.py` | PASS |
| Acceptance matrix | `python scripts/validate_acceptance.py` | PASS, 25 items |
| Runtime smoke | Playwright + HTTP checks | PASS: new-api 200, TapCanvas health 200, AI漫剧 link, SSO start 302, local login 410 |

## Simulated user flow

1. Sign-in click creates an HttpOnly state cookie and redirects with `audience=canvas`.
2. Provider callback validates state, exchanges one-time code, creates a server-side canvas session, and redirects to `/studio`.
3. Task submission filters the catalog, obtains a quote, reserves quota, invokes the model proxy, and returns `queued`.
4. Successful completion settles actual usage and refunds unused quota.
5. Proxy failure automatically settles with `failed` and refunds the full reservation.

## Limitations

The browser test uses the local PostgreSQL/Redis containers and local new-api SQLite runtime. A production acceptance test still requires the production domain, TLS, reverse proxy, and deployed new-api billing endpoints.
