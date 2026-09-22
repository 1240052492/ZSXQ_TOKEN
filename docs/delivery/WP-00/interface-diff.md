# WP-00 Interface Difference Register

状态：`in_progress`; this is a design/audit register, not an implemented contract.

| 领域 | New API baseline | LocalMiniDrama baseline | Required integration decision |
|---|---|---|---|
| Identity | Go auth/session/OAuth paths | Local Node JWT dependency and local configuration paths | New API is source of identity; canvas exchanges one-time SSO code and stores only platform user ID |
| Billing | quota, reservation, pricing, top-up/payment and usage paths | No platform wallet; local AI configuration and task execution | New API owns quote/reserve/settle/release; canvas emits business event and reservation reference |
| Models | model metadata, ability, pricing and channel constraints | local service configs and direct provider clients | New API catalog is filtered by enabled/canvas_enabled/capability/protocol |
| Tasks | relay/task plugin paths | local SQLite task/video workers | canvas task ID and node state map to platform request/reservation/settlement IDs |
| Storage | platform file/body storage options | local filesystem, asset service, upload and ZIP paths | introduce provider abstraction; local first, object storage/CDN later |
| Database | PostgreSQL-capable GORM service | single SQLite file and migrations | three PostgreSQL databases and separate migration/account boundaries |

Open contract artifacts required before WP-02/WP-04 implementation: OpenAPI or event schemas for SSO, model catalog, quote, reservation, proxy invocation, usage, settlement, refund, task callback and asset authorization.
