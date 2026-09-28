# OPC Service

This service is the controlled public boundary for the Agency Orchestrator
experience. It currently implements only the OPC SSO/session boundary; the AO
workflow API and worker are intentionally not exposed until the model, billing,
and per-user data contracts are implemented.

Required production variables:

- `NEW_API_BASE_URL`
- `OPC_PUBLIC_URL`
- `OPC_SSO_REDIRECT_URI`
- `OPC_SSO_INTERNAL_TOKEN`
- `OPC_SESSION_SECRET` (reserved for the persistent session implementation)

The in-memory `OpcSessionStore` is suitable for tests only. Production must
replace it with `opc_core`-backed sessions before enabling the navigation flag.
