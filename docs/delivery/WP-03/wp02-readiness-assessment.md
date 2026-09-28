# WP-02 Readiness Assessment

**Date:** 2026-09-29  
**Status:** Ready to proceed  
**Prerequisite:** WP-03 Lisa Deployment ✅ COMPLETE

## Executive Summary

WP-03 deployment successfully completed. All infrastructure services are running and healthy on Lisa server. Database initialization complete with proper security isolation. Ready to proceed with WP-02 three-parallel workflow.

## WP-02 Track Analysis

### Track 1: OPC Integration (Agency Orchestrator)

**Scope:** 11 work packages (OPC-00 through OPC-11)

**Current Status:**
- ✅ OPC-01: Navigation toggle implemented (default: disabled)
- ✅ OPC-02: opc-service deployed with health checks
- ✅ OPC-03: SSO authorization flow with secure one-time codes
- ⏳ OPC-04 to OPC-11: Not started

**Critical Dependencies:**
1. New API billing contract implementation (blocks OPC-06)
2. Model directory API (OPC-05)
3. opc_core persistent data model (OPC-04)
4. AO frontend derivation and capability stripping (OPC-07)

**Production Gate:**
- Cannot enable OPC switch until OPC-06 (billing) + OPC-10 (security) complete
- Current memory-only session storage must migrate to opc_core persistent storage

### Track 2: TapCanvas Integration (AI Comic Drama)

**Scope:** SSO complete, billing cutover pending

**Current Status:**
- ✅ SSO integration with New API complete
- ✅ Navigation toggle via HeaderNavModules.tapcanvas
- ✅ User/admin role mapping from New API
- ❌ Billing contract integration: Not implemented
- ❌ Local credit path removal: Blocked by billing contract

**Critical Dependencies:**
1. New API billing contract implementation (blocks production)
2. Server-to-server billing client with retry logic
3. Media/Agent production path cutover from local credits

**Production Gate:**
- Must set TAPCANVAS_LOCAL_BILLING_ENABLED=false
- All media/agent calls must use New API billing contract
- No local TapCanvas credit deduction allowed in production

### Track 3: New API Billing Contract (Foundation)

**Scope:** Unified billing infrastructure for both OPC and TapCanvas

**Contract Flow:**
```
quote → reserve → invoke → settle/refund
```

**Required Endpoints:**
- POST /internal/v1/billing/quote - Get pricing estimate
- POST /internal/v1/billing/reserve - Pre-authorize and hold funds
- POST /internal/v1/billing/invoke - Record actual invocation
- POST /internal/v1/billing/settle - Finalize charges based on actual usage
- POST /internal/v1/billing/refund - Release/refund for failures

**Resource Types:**
- LLM text generation (OPC primary use case)
- Image generation (TapCanvas + OPC)
- Video generation (TapCanvas)
- Audio/TTS generation (OPC)
- Agent orchestration (TapCanvas)
- Vision analysis (TapCanvas)

**Implementation Requirements:**
- Service authentication via OPC_SERVICE_TOKEN / TAPCANVAS_SSO_INTERNAL_TOKEN
- Idempotency-Key header support (prevent duplicate charges)
- User balance transaction isolation
- Audit trail with source tracking (source=opc, source=tapcanvas)
- Timeout and retry handling
- Run/step/task reference tracking (opc_run_id, opc_step_id, tapcanvas_task_id)

**Current Status:**
- ❌ Contract defined in contracts/platform-integration.openapi.yaml
- ❌ Implementation in New API not verified
- ❌ Deployment status unknown
- 🚫 **BLOCKS BOTH OPC AND TAPCANVAS**

## Dependency Graph

```
┌─────────────────────────────────────┐
│ New API Billing Contract Foundation │
│   (quote/reserve/invoke/settle)     │
└──────────────┬──────────────────────┘
               │
       ┌───────┴────────┐
       │                │
       ▼                ▼
┌─────────────┐  ┌──────────────┐
│  OPC Track  │  │ TapCanvas    │
│             │  │ Track        │
│ OPC-04 ──┐  │  │              │
│ OPC-05   │  │  │ Billing      │
│ OPC-06 ◄─┘  │  │ Client       │
│ OPC-07      │  │ Integration  │
│ OPC-08      │  │              │
│ OPC-09      │  │ Media/Agent  │
│ OPC-10      │  │ Cutover      │
│ OPC-11      │  │              │
└─────────────┘  └──────────────┘
```

## Critical Path Analysis

### Phase 1: Foundation (Priority 1 - Blocks everything)
**Estimated: 3-5 days**

1. **Implement New API billing contract** (CRITICAL - unblocks both tracks)
   - quote/reserve/invoke/settle/refund endpoints
   - Idempotency handling
   - User balance management
   - Transaction isolation
   - Audit logging with source tracking
   - Error handling and refund logic

2. **Parallel independent work:**
   - OPC-04: opc_core schema migrations (database work)
   - OPC-05: Model directory API (can start independently)
   - TapCanvas: Billing client skeleton (can prepare integration)

### Phase 2: Integration (Priority 2)
**Estimated: 5-7 days**

**OPC Track:**
- OPC-06: Connect to billing contract (depends on Phase 1)
- OPC-07: AO frontend derivation (complex, multi-file work)

**TapCanvas Track:**
- Complete billing client implementation
- Integration testing with New API billing
- Remove local credit paths from media/agent flows

### Phase 3: Completion (Priority 3)
**Estimated: 7-10 days**

**OPC Track:**
- OPC-08: Workflow execution engine with state machine
- OPC-09: Expert/creative libraries and asset management
- OPC-10: Security and E2E acceptance testing
- OPC-11: Deployment preparation and rollback procedures

**TapCanvas Track:**
- Production cutover validation
- Set TAPCANVAS_LOCAL_BILLING_ENABLED=false
- Production monitoring setup

### Phase 4: Production Release
**Estimated: 2-3 days**

- Gradual rollout with backend toggles
- Real-time monitoring (SSO success rate, billing errors, worker queues)
- Rollback procedures validated
- User acceptance testing

## Infrastructure Status (WP-03 Complete)

### Lisa Server (172.247.109.6)

**Services Running:**
- ✅ platform-gateway:v0.1.3 (port 3000) - Healthy
- ✅ super-canvas-adapter:v0.1.3 (port 3001) - Healthy
- ✅ opc-service:v0.1.3 (port 3002) - Healthy
- ✅ zsxq-new-api (port 3100) - Healthy
- ✅ zsxq-postgres (port 5432) - Healthy
- ✅ zsxq-redis (port 6379) - Healthy

**Databases Configured:**
- ✅ new_api - 3 roles (owner/migration/runtime), schema ownership fixed
- ✅ opc_core - 3 roles (owner/migration/runtime), ready for OPC-04 migrations
- ✅ super_canvas - 3 roles (owner/migration/runtime), ready for TapCanvas data

**Network:**
- ✅ Docker network: zsxq-network
- ✅ External access verified on all service ports
- ✅ Internal DNS resolution working

**Security:**
- ✅ Runtime users cannot perform DDL operations (verified)
- ✅ Cross-database access properly isolated
- ✅ Schema permissions configured correctly
- ✅ Credentials secured (not in logs/code)

## Recommended Next Actions

### Immediate (Today)

1. **Verify New API billing contract implementation status**
   - Check if /internal/v1/billing/* endpoints exist in vendor/new-api
   - Verify deployment status on Lisa new-api service
   - Test endpoints with OPC_SERVICE_TOKEN authentication

2. **If billing contract NOT implemented:**
   - Start Phase 1: Implement billing contract endpoints
   - This is the critical path blocker for all WP-02 work

3. **If billing contract IS implemented:**
   - Start parallel tracks:
     - OPC-04: Begin opc_core schema migrations
     - OPC-05: Implement model directory API
     - TapCanvas: Implement billing client

### Short-term (This week)

- Complete Phase 1 foundation work
- Begin Phase 2 integration work
- Maintain WP-03 deployment health

### Medium-term (Next 2-3 weeks)

- Complete OPC-06 through OPC-11
- Complete TapCanvas billing cutover
- Execute OPC-10 security acceptance
- Prepare production release

## Risks and Mitigations

### Risk 1: Billing Contract Implementation Complexity
**Impact:** High - blocks both tracks  
**Mitigation:** 
- Prioritize as Phase 1 critical path
- Use existing contract specification in contracts/platform-integration.openapi.yaml
- Implement with comprehensive testing and rollback capability

### Risk 2: AO Frontend Derivation (OPC-07)
**Impact:** Medium - complex multi-file work  
**Mitigation:**
- Detailed planning before execution
- Maintain upstream license compliance (Apache-2.0)
- Strip dangerous capabilities systematically (Provider config, CLI, MCP, etc.)

### Risk 3: Production Cutover Coordination
**Impact:** High - affects live users  
**Mitigation:**
- Backend toggles allow instant rollback
- Gradual rollout with monitoring
- Comprehensive E2E testing (OPC-10) before release

### Risk 4: Database Migration Safety
**Impact:** Medium - data integrity risk  
**Mitigation:**
- Migrations tested in development first
- Backup procedures validated (WP-03 complete)
- Rollback scripts prepared alongside migrations

## Success Criteria

### WP-02 Complete Definition

**OPC Track:**
- ✅ All OPC-00 through OPC-11 work packages complete
- ✅ OPC-10 security acceptance passed
- ✅ Production toggle enabled for pilot users
- ✅ Billing integration verified with actual charges

**TapCanvas Track:**
- ✅ Billing contract integration complete
- ✅ TAPCANVAS_LOCAL_BILLING_ENABLED=false in production
- ✅ All media/agent flows using New API billing
- ✅ Local credit paths completely removed

**Infrastructure:**
- ✅ New API billing contract deployed and operational
- ✅ Monitoring and alerting configured
- ✅ Rollback procedures validated
- ✅ Documentation complete

## Authorization Status

User has granted authorization for non-high-risk operations on Lisa server:
> "授权你可以进行lisa服务器上的任何非高危操作"

This authorization covers:
- ✅ Service deployment and restart
- ✅ Database migrations (with backup)
- ✅ Configuration updates
- ✅ Log inspection and debugging
- ✅ Health check verification

User confirmation required for:
- ⚠️ Production data deletion
- ⚠️ Security policy changes
- ⚠️ External service integration
- ⚠️ Billing rule modifications

## Conclusion

WP-03 infrastructure deployment is complete and verified. All services are healthy and ready to support WP-02 development work.

**Critical blocker:** New API billing contract implementation status must be verified immediately. This is the foundation that unblocks both OPC and TapCanvas tracks.

**Recommended action:** Investigate New API billing contract implementation status and proceed accordingly with Phase 1 foundation work.
