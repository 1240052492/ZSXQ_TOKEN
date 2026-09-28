# WP-01 Next Steps Action Plan

**Generated**: 2026-09-28  
**Context**: WP-01 Infrastructure Baseline completed, pending human review before WP-02 launch  
**Status**: ✅ Technical completion achieved, 🔴 Manual approvals required

---

## Human Review Checklist

### 🔴 CRITICAL PATH (Blocks WP-02)

#### 1. Database Infrastructure Review (DBA)

**Priority**: P0 - Must complete within 48 hours  
**Estimated Time**: 4-6 hours  
**Required Approver**: Database Administrator + Infrastructure Lead

**Action Items**:

- [ ] **Review database initialization DDL**
  - File: `db/init/00-create-databases.sql`
  - Compare with existing `infra/postgres/roles.sql`
  - Resolve role naming conflicts (NOLOGIN groups vs dedicated owner roles)
  - Document role conversion strategy for existing environments

- [ ] **Approve nine-role permission matrix**
  - Review security model: owner (NOLOGIN) / migration (LOGIN, NOINHERIT) / runtime (LOGIN)
  - Validate separation of concerns (DDL vs DML, cross-database isolation)
  - Confirm no SUPERUSER/CREATEDB/CREATEROLE/BYPASSRLS grants

- [ ] **Execute database initialization on staging**
  - Provision staging PostgreSQL cluster (if not exists)
  - Execute `db/init/00-create-databases.sql` with cluster admin privileges
  - Create three databases: `new_api`, `opc_core`, `super_canvas`
  - Create nine roles: `zsxq_{new_api,opc_core,super_canvas}_{owner,migration,runtime}`

- [ ] **Verify permission isolation**
  - Run privilege probe: runtime accounts cannot execute DDL
  - Run privilege probe: runtime accounts cannot CONNECT to other databases
  - Run privilege probe: migration accounts can SET ROLE to owner
  - Confirm no cross-database foreign keys exist

- [ ] **Test cross-database FK check script**
  - Execute `db/scripts/check-cross-db-fk.sql` on all three databases
  - Verify script correctly detects violations (if any)
  - Document any exceptions or remediation required

- [ ] **Plan New API GORM AutoMigrate separation**
  - Analyze `vendor/new-api/model/main.go` GORM AutoMigrate behavior
  - Design DDL extraction into migration account workflow
  - Document compatibility plan for strict runtime permissions
  - Timeline: Before production deployment (not blocking WP-02 start)

**Deliverables**:
- ✅ DBA sign-off document
- ✅ Staging database initialization evidence (psql logs, role dumps)
- ✅ Privilege probe test results
- ✅ New API DDL separation plan (timeline + milestones)

---

#### 2. Security & Secrets Review (SecOps)

**Priority**: P0 - Must complete within 48 hours  
**Estimated Time**: 2-3 hours  
**Required Approver**: Security Team Lead

**Action Items**:

- [ ] **Review secret generation strategy**
  - File: `scripts/generate-secrets.sh`
  - Validate cryptographic strength (openssl rand -base64)
  - Approve minimum key lengths:
    - SERVICE_TOKEN_SECRET: ≥64 characters
    - JWT_SECRET: ≥32 characters
    - SESSION_SECRET: ≥32 characters
    - OPC_SSO_INTERNAL_TOKEN: ≥32 characters

- [ ] **Generate secrets for all environments**
  - Development: Execute `bash scripts/generate-secrets.sh` and save to `.env.local`
  - Staging: Generate unique secrets for staging environment
  - Production: Generate unique secrets for production environment
  - Document secret inventory with generation timestamps

- [ ] **Deploy secrets to secure storage**
  - **Development**: Store in `.env.local` (gitignored, local only)
  - **Staging/Production**: Choose approved storage:
    - Option A: Kubernetes Secrets (with encryption at rest)
    - Option B: HashiCorp Vault
    - Option C: AWS Secrets Manager
    - Option D: Azure Key Vault
  - Verify secrets are NOT committed to git repository
  - Configure service access permissions

- [ ] **Configure rotation schedules**
  - JWT_SECRET: 90-day rotation cycle
  - SESSION_SECRET: 90-day rotation cycle
  - SERVICE_TOKEN_SECRET: 180-day rotation cycle
  - OPC_SSO_INTERNAL_TOKEN: 180-day rotation cycle
  - Set calendar reminders or automated rotation (if supported)

- [ ] **Enable audit logging**
  - Configure SERVICE_TOKEN usage logging
  - Set 180-day retention policy
  - Define log analysis and alerting rules
  - Document breach response procedures

- [ ] **Validate secret management documentation**
  - File: `docs/delivery/WP-01/environment-config.md`
  - Review secret generation procedures
  - Review rotation procedures
  - Review breach response procedures
  - Approve for production use

**Deliverables**:
- ✅ Security team sign-off document
- ✅ Secret inventory with generation timestamps
- ✅ Deployment evidence (screenshots, audit logs)
- ✅ Rotation schedule documented
- ✅ Audit logging configuration verified

---

#### 3. Architecture Review (Tech Lead)

**Priority**: P0 - Should complete within 72 hours  
**Estimated Time**: 2-3 hours  
**Required Approver**: Principal Architect + Product Owner

**Action Items**:

- [ ] **Approve three-database isolation strategy**
  - Review architecture: `docs/delivery/WP-01/database-architecture.md`
  - Confirm no cross-database business foreign keys acceptable
  - Validate consistency strategy: service APIs + idempotent events + compensation
  - Approve service boundaries and data ownership

- [ ] **Validate service contract completeness**
  - Review: `docs/delivery/WP-01/service-contracts.md`
  - Review: `api/contracts/new-api-internal.openapi.yaml`
  - Confirm all WP-02 requirements covered:
    - SSO authorization code exchange
    - Model catalog query (with canvas filtering)
    - Wallet balance query
    - Quota reservation (with idempotency)
    - Controlled model proxy invocation
    - Usage settlement
    - Refund processing
  - Approve error handling and retry strategies

- [ ] **Review environment variable taxonomy**
  - Review: `docs/delivery/WP-01/environment-config.md`
  - Confirm 26 environment variables appropriate:
    - 6 service configuration
    - 3 service addresses
    - 9 database connections (3×3)
    - 4 core secrets
    - 4 optional features (Redis, object storage)
  - Approve configuration layer design

- [ ] **Approve authentication mechanism**
  - Review Bearer token + X-Service-Name header design
  - Validate timing-safe comparison implementation
  - Confirm SERVICE_TOKEN distribution strategy
  - Approve 180-day rotation cycle

- [ ] **Sign off on migration strategy**
  - New API: Retain GORM AutoMigrate (with future DDL separation plan)
  - OPC Service: Use golang-migrate compatible versioned migrations
  - Super Canvas: Use golang-migrate compatible versioned migrations
  - Approve independent versioning per database
  - Confirm migration account SET ROLE requirements

**Deliverables**:
- ✅ Architecture sign-off document
- ✅ Service contract approval
- ✅ Risk assessment and mitigation plan
- ✅ WP-02 implementation authorization

---

### 🟢 NON-CRITICAL PATH (Can proceed in parallel)

#### 4. DevOps Configuration (DevOps Engineer)

**Priority**: P1 - Complete within 1 week  
**Estimated Time**: 3-4 hours  
**Required Approver**: DevOps Engineer

**Action Items**:

- [ ] **Validate development environment**
  - Execute: `npm run validate-env` in development
  - Document any missing environment variables
  - Create `.env.local` with appropriate development values
  - Test: `npm test` should pass (24 tests)

- [ ] **Configure staging environment**
  - Populate `*_DATABASE_URL` variables with staging credentials:
    - `NEW_API_DATABASE_URL`
    - `OPC_CORE_DATABASE_URL`
    - `SUPER_CANVAS_DATABASE_URL`
  - Configure service addresses:
    - `NEW_API_BASE_URL`
    - `OPC_PUBLIC_URL`
    - `CANVAS_APP_URL`
  - Deploy secrets from SecOps
  - Test: Services can connect to databases and each other

- [ ] **Test unified configuration loader**
  - File: `services/lib/config-loader.js`
  - Test in development environment
  - Test in staging environment
  - Verify type conversion (string → number, boolean)
  - Verify required field validation
  - Verify default value behavior

- [ ] **Add version lock files** (Advisory from integration verification)
  - Create `.nvmrc` with content: `24.18.0`
  - Create `.python-version` with content: `3.14.3`
  - Update Dockerfile base images to pin versions
  - Document version upgrade process

- [ ] **Integrate SQL syntax check into CI** (Advisory from integration verification)
  - Add PostgreSQL syntax validation step to `.github/workflows/acceptance-gate.yml`
  - Example: `psql --dry-run -f db/init/00-create-databases.sql`
  - Example: `psql --dry-run -f db/scripts/check-cross-db-fk.sql`
  - Ensure no database connection required for syntax-only checks

- [ ] **Create service README files** (Advisory from repo topology analysis)
  - `services/super-canvas-adapter/README.md`:
    - Service purpose and responsibilities
    - Environment variables required
    - Build and test commands
    - Integration points (New API, Canvas frontend)
  - Similar READMEs for `opc-service` and `platform-gateway`

**Deliverables**:
- ✅ Development environment validated
- ✅ Staging environment configured and tested
- ✅ Version lock files added
- ✅ CI enhancements deployed
- ✅ Service documentation complete

---

## WP-02 Launch Criteria

**WP-02 can begin when**:

✅ **Ready Now**:
- [x] Integration tests passing (24 unit tests + 5 smoke checks)
- [x] OpenAPI contract defined (`api/contracts/new-api-internal.openapi.yaml`)
- [x] Environment variable validation tooling ready
- [x] Database architecture documented
- [x] Service topology documented

🔴 **Blocking (Must Complete)**:
- [ ] DBA sign-off received
- [ ] Security sign-off received
- [ ] Architecture sign-off received
- [ ] Staging database initialized
- [ ] Development secrets deployed

🟡 **Recommended (Can Proceed in Parallel)**:
- [ ] Production database initialized
- [ ] Production secrets deployed
- [ ] CI enhancements deployed
- [ ] Version lock files added

**Estimated Ready Date**: 2026-09-30 (assuming 48-hour review cycle)

---

## Timeline & Milestones

### Week 1 (2026-09-28 to 2026-10-04)

**Day 1-2 (Sep 28-29)**: Critical Path Reviews
- DBA review session (4-6 hours)
- Security review session (2-3 hours)
- Architecture review session (2-3 hours)
- **Milestone**: All sign-offs received

**Day 3 (Sep 30)**: Staging Deployment
- Execute staging database initialization
- Deploy development/staging secrets
- Validate environment configuration
- **Milestone**: WP-02 launch authorized

**Day 4-5 (Oct 1-2)**: WP-02 Sprint 1
- Implement SSO authorization code exchange endpoint
- Implement model catalog query endpoint (with canvas filtering)
- Implement wallet balance query endpoint
- Write integration tests

**Day 6-7 (Oct 3-4)**: WP-02 Sprint 2
- Implement quota reservation endpoint (with idempotency)
- Implement controlled model proxy invocation
- Implement usage settlement and refund endpoints
- End-to-end integration testing

### Week 2 (2026-10-05 to 2026-10-11)

**Day 8-10 (Oct 5-7)**: Production Readiness
- Production database initialization (post-DBA final approval)
- Production secret deployment (post-Security final approval)
- Load testing and performance tuning
- Security penetration testing

**Day 11-12 (Oct 8-9)**: Documentation & Training
- Update runbooks with operational procedures
- Create incident response playbooks
- Team training on new architecture
- Knowledge transfer sessions

**Day 13-14 (Oct 10-11)**: Production Deployment
- Blue-green deployment to production
- Smoke testing in production
- Monitoring and alerting validation
- **Milestone**: WP-02 production deployment complete

---

## Risk Mitigation

### Risk 1: Database Reconciliation Complexity
**Probability**: Medium | **Impact**: High | **Status**: 🔴 Active

**Description**: Existing `infra/postgres/roles.sql` uses NOLOGIN group roles; reconciling with new nine-role architecture may reveal conflicts.

**Mitigation**:
- DBA to create detailed reconciliation plan before execution
- Test reconciliation in isolated staging environment first
- Document rollback procedures
- Allow 2-3 days buffer for unforeseen issues

**Contingency**: If reconciliation blocked, defer New API to existing roles and only apply new architecture to OPC/Canvas databases.

---

### Risk 2: New API GORM AutoMigrate Incompatibility
**Probability**: High | **Impact**: Medium | **Status**: 🟡 Monitoring

**Description**: Strict runtime permissions may break New API startup DDL execution.

**Mitigation**:
- Document GORM behavior before making permission changes
- Create DDL extraction plan with clear timeline
- Test in staging with permissive runtime first, then tighten
- Allow WP-02 to proceed with permissive New API runtime initially

**Contingency**: Grant temporary DDL permissions to New API runtime in staging/production until separation complete (document as technical debt).

---

### Risk 3: Secret Rotation Operational Burden
**Probability**: Low | **Impact**: Medium | **Status**: 🟢 Monitoring

**Description**: 90/180-day rotation cycles require operational discipline; missed rotations could impact security posture.

**Mitigation**:
- Set up automated calendar reminders 30/60 days before expiration
- Document rotation procedures in runbooks
- Integrate with secret management platform automation (if available)
- Define escalation path if rotation missed

**Contingency**: Manual rotation with incident review if automated rotation unavailable.

---

### Risk 4: Documentation Drift
**Probability**: Medium | **Impact**: Low | **Status**: 🟢 Monitoring

**Description**: 2,700 lines of documentation may become stale as implementation progresses.

**Mitigation**:
- Add documentation review to PR checklist
- Quarterly documentation audit cycle
- Assign documentation owner per work package
- Use evidence links in acceptance matrix to track updates

**Contingency**: Dedicate sprint capacity to documentation refresh if drift detected.

---

## Communication Plan

### Stakeholder Updates

**Daily Standups** (During WP-02):
- Progress on WP-02 implementation tasks
- Blockers requiring escalation
- Test results and quality metrics

**Weekly Status Reports**:
- Work package completion status
- Acceptance matrix progress
- Risk register updates
- Timeline adjustments

**Review Sessions**:
- DBA Review: Schedule within 24 hours (Sep 29)
- Security Review: Schedule within 24 hours (Sep 29)
- Architecture Review: Schedule within 48 hours (Sep 30)
- WP-02 Kickoff: Schedule after all sign-offs (Oct 1)

### Escalation Path

**Level 1 (Technical)**: Development team resolves implementation issues  
**Level 2 (Cross-functional)**: Tech lead coordinates with DBA/Security/DevOps  
**Level 3 (Executive)**: Product owner escalates timeline/resource constraints  

---

## Success Criteria

WP-01 considered **fully complete** when:

- [x] All design documents delivered (7 files, 2,700 lines)
- [x] All infrastructure scripts delivered (7 scripts)
- [x] All API contracts delivered (OpenAPI + Pact tests)
- [x] Integration verification passed (18/18 checks)
- [x] Test suite passing (24 unit tests + 5 smoke checks)
- [ ] DBA sign-off received
- [ ] Security sign-off received  
- [ ] Architecture sign-off received
- [ ] Staging database initialized
- [ ] Secrets deployed to development/staging
- [ ] Acceptance matrix M02 and M05 marked `in_progress` with evidence links ✅
- [ ] WP-02 authorized to launch

**Current Status**: 6/11 complete (55%)  
**Estimated Completion**: 2026-09-30 (2 days remaining)

---

## Contact Information

**Technical Questions**: @1240052492  
**DBA Review**: [Schedule via internal calendar]  
**Security Review**: [Schedule via internal calendar]  
**Architecture Review**: [Schedule via internal calendar]

**Documentation**:
- Completion Report: `docs/delivery/WP-01/completion-report.md`
- Workflow Evidence: `.loop/evidence/WP-01-infrastructure-report.md`
- Acceptance Matrix: `docs/acceptance/matrix.json`
