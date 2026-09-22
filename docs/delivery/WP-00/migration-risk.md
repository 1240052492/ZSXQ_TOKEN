# WP-00 Migration Risk Register

状态：`blocked` until source and legal baselines are archived.

| 风险 | 等级 | 当前判断 | 关闭条件 |
|---|---|---|---|
| LocalMiniDrama SQLite data moved into shared business tables | P0 | Do not copy tables directly | Define explicit import mapping into `super_canvas`; preserve source IDs and audit provenance |
| Local accounts/JWT remain active | P0 | Direct replacement required | SSO path passes and local password/token routes are removed or isolated |
| Local provider keys bypass New API | P0 | Direct client paths exist upstream | Secrets move to New API/provider boundary; canvas service account cannot read them |
| New API quota semantics differ from canvas task pricing | P0 | Contract not yet implemented | Quote/reserve/settle/refund state machine and idempotency tests pass |
| Model/channel failover silently changes model or price | P0 | Must be prevented by snapshot validation | Same `platform_model_id` and price version are enforced and audited |
| AGPL obligations and fork rights misunderstood | P0 | Specialist review pending | Signed review covers source offer, attribution, NOTICE, fork maintenance and deployment boundary |
| Local asset paths become invalid after provider migration | P1 | Provider abstraction required | Migration manifest, dual-read/cutover and deletion/cache invalidation tests pass |
| Async worker retries duplicate charge or output | P0 | Idempotency not implemented | Fault injection and ledger reconciliation pass |
