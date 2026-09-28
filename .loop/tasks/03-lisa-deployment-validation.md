# LOOP-ENV-01 Lisa deployment and validation

- **Objective**: deploy the current New API, TapCanvas adapter, and OPC integration baseline to Lisa and run the declared formalized validation suite against the deployed environment.
- **Owner**: coordinator
- **Environment**: Lisa via SSH alias `lisa`; Ubuntu 24.04.1; Docker 29.7.2; Compose 5.5.0; domain `aiplantform.site`.
- **Scope**: deployment packaging, service routing, TLS, New API integration, TapCanvas and OPC service checks, API/integration/data/user-simulation/smoke evidence.
- **Out of scope**: video-model tests, public production release, arbitrary changes to existing unrelated services, direct provider/API-key exposure, CLI/Shell/filesystem/callback/MCP capabilities.
- **DNS/TLS**: `token.aiplantform.site`, `canvas.aiplantform.site`, and `opc.aiplantform.site`; certificate is managed by Certbot on Lisa.
- **Budget**: real upstream model calls capped at USD 10 per day; video models excluded.
- **Allowed repository files**: `.loop/tasks/03-lisa-deployment-validation.md`, `.loop/evidence/`, `docs/delivery/`, `STATE.md`, and deployment files created for this task only.
- **Infrastructure boundary**: Lisa changes are authorized for this task; do not touch `main`, unrelated containers, unrelated data, or production secrets.
- **Acceptance IDs**: D01-D05, F01-F08, C01-C06, S01-S05, plus Lisa TLS/routing/health evidence.
- **Test command**: `npm test`; remote service checks and the acceptance matrix must also return success or be explicitly recorded as blocked.
- **Lint command**: `npm run loop:lint` and `git diff --check`.
- **effective_max_loops**: 5.
- **Hard exit**: declared tests exit 0, lint has no new errors, remote evidence is reproducible, and independent acceptance/security reviews pass.
- **Stop conditions**: missing SSH/DNS/secret authority; disk or memory exhaustion; any security boundary violation; test command failure after 5 loops; unverified or destructive recovery state.
- **Escalation owner**: human approver.
