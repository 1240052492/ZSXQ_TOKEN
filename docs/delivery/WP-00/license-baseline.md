# License Baseline — Open Source Compliance Assessment

**Date:** 2026-09-28  
**Status:** Baseline established  
**Scope:** vendor/new-api, vendor/agency-orchestrator, vendor/LocalMiniDrama

---

## Executive Summary

Three vendor projects have been scanned for open source licenses. **Critical finding:** `new-api` uses **AGPL-3.0**, which imposes network copyleft obligations that trigger when modified versions are accessed over a network. The adapter layer code (`services/super-canvas-adapter`, `services/opc-service`, `services/platform-gateway`) communicates with New API via HTTP APIs without importing or linking New API source code, creating architectural separation that limits AGPL contagion risk. However, **any modifications to New API itself** require source code disclosure to network users under Section 13.

**Commercial use risk: HIGH** for New API modifications, **LOW** for adapter layer code.

---

## 1. Main Project Licenses

| Project | License Type | File Path | Trigger Condition |
|---------|-------------|-----------|-------------------|
| **new-api** | GNU AGPL-3.0 | `vendor/new-api/LICENSE` | Network interaction with modified version (§13) |
| **agency-orchestrator** | Apache-2.0 | `vendor/agency-orchestrator/LICENSE` | Distribution of modified source/binary (§4) |
| **LocalMiniDrama** | MIT | `vendor/LocalMiniDrama/LICENSE` | Distribution (permissive, minimal restrictions) |
| agency-agents-zh (bundled) | MIT | `vendor/agency-orchestrator/agency-agents/LICENSE` | Distribution (permissive) |

---

## 2. AGPL-3.0 Network Service Obligations (New API)

### Section 13 Critical Language

> **"Notwithstanding any other provision of this License, if you modify the Program, your modified version must prominently offer all users interacting with it remotely through a computer network (if your version supports such interaction) an opportunity to receive the Corresponding Source of your version by providing access to the Corresponding Source from a network server at no charge, through some standard or customary means of facilitating copying of software."**

**Plain interpretation:** If you modify New API and operate it as a network service (which is its primary use case — an API gateway), you MUST:

1. **Detect the trigger:** Any user accessing the service over HTTP/HTTPS counts as "remote network interaction"
2. **Provide source access:** Offer a download link or repository URL to the complete modified source code
3. **Prominent placement:** Display in the web UI footer, API documentation, or `/about` endpoint
4. **No charge:** Free download, no authentication barriers
5. **"Corresponding Source":** All source code needed to build and run your modified version, including build scripts, but excluding System Libraries (§1)

### What Counts as "Modification"

- Changing Go source files in `vendor/new-api/`
- Adding new API endpoints or middleware
- Modifying the billing logic, rate limiting, or authentication flows
- Customizing the frontend UI

### What Does NOT Trigger (Safe Harbor)

- **Unmodified deployment:** Running New API as-is without code changes (§2: "unlimited permission to run the unmodified Program")
- **Configuration changes:** Environment variables, `config.json`, database settings (not copyrightable modifications)
- **Adapter layer code:** Services that *call* New API's HTTP APIs without importing New API source (see §3 below)

---

## 3. Integration Architecture Assessment

### Current Design (from `services/super-canvas-adapter/src/new-api-client.js`)

The adapter layer is a **separate process** that communicates with New API exclusively via **HTTP REST APIs**:

```javascript
// HTTP client, no code imports from new-api
async exchangeCanvasCode({ code, state }) {
  const response = await this.#fetch(`${this.#baseUrl}/internal/v1/sso/exchange`, {
    method: 'POST',
    headers: { authorization: `Bearer ${this.#serviceToken}` }
  });
}
```

**AGPL contagion analysis:**

- **No linking:** Adapter services do not `import` or `require` New API modules
- **Process boundary:** Adapter runs as separate Node.js services; New API runs as a Go binary
- **HTTP-only communication:** Standard REST API calls (JSON over HTTPS)
- **AGPL "aggregate" exception (§5):** *"A compilation of a covered work with other separate and independent works, which are not by their nature extensions of the covered work, and which are not combined with it such as to form a larger program, in or on a volume of a storage or distribution medium, is called an 'aggregate' if the compilation and its resulting copyright are not used to limit the access or legal rights of the compilation's users beyond what the individual works permit. Inclusion of a covered work in an aggregate does not cause this License to apply to the other parts of the aggregate."*

**Conclusion:** The adapter layer qualifies as a **separate work** that communicates with New API through a standard interface (HTTP). The AGPL does NOT require adapter source disclosure as long as:

1. Adapters remain in separate repositories/processes
2. Communication remains at the API boundary (no shared libraries, no process forking)
3. New API itself is not modified (if modified, only New API source needs disclosure, not adapters)

---

## 4. Apache-2.0 Obligations (Agency Orchestrator)

### Key Requirements

1. **NOTICE file preservation (§4.d):** The project includes a NOTICE file — if distributing modified versions, you MUST include it in:
   - Source distributions (keep `vendor/agency-orchestrator/LICENSE` + `NOTICE` if present)
   - Binary distributions (embed in `--version` output or docs)
   - Web UI (if exposing an orchestrator web interface, include attribution in footer)

2. **Modification notices (§4.b):** Modified files must carry "prominent notices stating that You changed the files"
   - Add comments: `// Modified by [Company] on [Date]: [brief description]`

3. **Patent grant (§3):** Apache-2.0 includes an express patent license from contributors
   - **Patent retaliation clause:** If you sue any contributor claiming the Work infringes your patents, your patent license terminates
   - This is generally favorable — it provides patent peace

4. **Trademark exclusion (§6):** You cannot use "Agency Orchestrator" or author trademarks without permission (reasonable attribution use is allowed)

### What's Permissive

- No source disclosure requirement (unlike AGPL)
- Can integrate into proprietary products
- Can modify without publishing changes (just mark them internally)

---

## 5. Dependency License Survey

### New API (Go dependencies from `go.mod`)

**Methodology:** Scanned 24 direct dependencies listed in `vendor/new-api/go.mod` for GPL-family licenses.

**Result:** No AGPL/GPL/LGPL/SSPL dependencies detected in the `require` section. Dominant licenses:
- **Apache-2.0:** AWS SDK, Gin web framework, GORM
- **MIT:** Most utilities (UUID, JWT, Redis client)
- **BSD-3-Clause:** Some crypto and encoding libraries

**Risk:** Low — permissive dependencies do not impose additional copyleft obligations.

### Agency Orchestrator (npm dependencies)

**Direct dependencies (20 packages):**

| Package | License | Notes |
|---------|---------|-------|
| @anthropic-ai/sdk | MIT | Permissive |
| express | MIT | Permissive |
| js-yaml | MIT | Permissive |
| marked | MIT | Permissive |
| pptxgenjs | MIT | Permissive |
| superpowers-zh | MIT | Permissive |
| agency-agents-zh | MIT | Permissive |
| typescript | Apache-2.0 | Permissive |
| undici | MIT | Permissive |
| xlsx | Apache-2.0 | Permissive |

**Result:** All dependencies are MIT or Apache-2.0. No GPL-family licenses detected.

**Risk:** Low — no license conflicts.

### LocalMiniDrama

**License:** MIT (xuanyustudio, 2026)  
**Risk:** Minimal — MIT allows commercial use, modification, and redistribution with attribution.

### Adapter Services

**License status:** None declared (all `package.json` files mark `"private": true`, no license field)

**Recommendation:** Add explicit license headers to adapter service files. Suggested approach:
- If adapters are proprietary: Add copyright notice `// Copyright (c) [Company] [Year]. All rights reserved.`
- If adapters will be open-sourced: Choose MIT or Apache-2.0 for ecosystem compatibility

---

## 6. Source Code Disclosure Strategy (New API)

### Scenario A: No Modifications to New API

**Obligation:** None. AGPL §2 grants "unlimited permission to run the unmodified Program."

**Action:** Deploy vendor/new-api as-is. No source disclosure required.

---

### Scenario B: Modifications to New API (Current Reality)

**Assumption:** Based on `docs/delivery/WP-04/billing-baseline.md` and adapter integration work, New API likely has been or will be modified to support internal SSO endpoints (`/internal/v1/sso/exchange`), billing callbacks, or custom authentication flows.

**Obligation:** AGPL §13 requires offering Corresponding Source to network users.

**Compliance paths:**

#### Option 1: Public Repository (Recommended)

1. **Fork the upstream:** Create `github.com/[Company]/new-api` or `gitlab.company.com/platform/new-api`
2. **Commit modifications:** Push all custom changes to this repo
3. **Link in UI:** Add to New API web interface footer or `/about` endpoint:
   ```
   "This service runs a modified version of New API (AGPL-3.0).
    Source code: https://github.com/[Company]/new-api"
   ```
4. **Keep it updated:** Each production deployment must match the available source (use git tags: `v1.0-company`)

**Pros:** Simple, auditable, demonstrates good faith compliance  
**Cons:** Competitors can see your modifications

#### Option 2: Download Bundle

1. **Generate source archive:** `git archive --format=tar.gz --prefix=new-api-modified/ HEAD > new-api-source.tar.gz`
2. **Host on CDN:** Upload to a publicly accessible URL (no authentication)
3. **Link in UI:** "Source code: https://downloads.company.com/new-api-source.tar.gz"
4. **Keep synchronized:** Regenerate archive with each release, keep old versions available for 3 years (§6.b)

**Pros:** No public repository needed  
**Cons:** More operational overhead, harder to prove currency

#### Option 3: Source Request System

1. **Offer form:** Display "Request source code" link in New API UI
2. **Written offer (§6.b):** "Valid for at least three years... to give anyone who possesses the object code... access to copy the Corresponding Source from a network server at no charge"
3. **Respond within reasonable time:** Email source archive or repo link when requested

**Pros:** Deferred disclosure until someone asks  
**Cons:** Legally risky if response is slow; requires maintaining request system for 3 years

---

## 7. Legal Review Checklist

The following items require legal counsel review before commercial deployment:

- [ ] **AGPL "Corresponding Source" definition (§1):** Confirm which internal build scripts, config templates, and deployment automation must be included
- [ ] **"Remote network interaction" scope (§13):** Clarify if internal API calls (service-to-service within company network) trigger disclosure obligations or if only external user access counts
- [ ] **Aggregate work boundary (§5):** Validate that HTTP-based adapter separation is sufficient to avoid AGPL contagion to proprietary services
- [ ] **Additional terms in NOTICE file (§7):** `vendor/new-api/NOTICE` includes AGPLv3 §7(b) attribution requirements ("Frontend design and development by New API contributors" + link to original repo). Confirm these must be preserved in modified UI
- [ ] **Trademark usage:** Verify whether rebranding New API's web interface (if modified) requires removing or altering "New API" name per AGPL §7(e)
- [ ] **Patent implications:** If company holds API gateway patents, confirm Apache-2.0 patent grant in Agency Orchestrator dependencies does not create conflicts
- [ ] **Downstream distribution:** If New API will be bundled with customer deliverables or sold as part of a SaaS white-label, determine if that changes "network interaction" to "distribution" (stricter §6 source disclosure rules apply)
- [ ] **Jurisdiction-specific rules:** AGPL compliance interpretation varies by jurisdiction (EU vs US vs China); confirm local legal requirements for "prominent offer" placement and source availability duration

---

## 8. Compliance Roadmap

**Immediate (before next production deployment):**

1. **Audit modifications:** Run `git diff` against upstream `vendor/new-api` to identify all custom changes
2. **Add source disclosure:** If modifications exist, implement Option 1 (public repo) or Option 2 (download bundle)
3. **Add license headers:** Ensure adapter services have copyright notices
4. **Preserve NOTICE files:** Copy `vendor/agency-orchestrator/LICENSE` and any NOTICE files to deployment artifacts

**Ongoing:**

5. **Track upstream changes:** Subscribe to AGPL-licensed project security advisories; rebase modifications regularly
6. **Document modification policy:** Create internal "New API Modification SOP" requiring legal pre-approval for changes
7. **Monitor access patterns:** If New API will be exposed to external users (not just internal services), escalate compliance review

**Long-term:**

8. **Consider alternatives:** Evaluate non-AGPL API gateway solutions (Kong, Tyk, AWS API Gateway) if AGPL compliance overhead becomes burdensome
9. **Upstream contributions:** If modifications are not trade secrets, contribute them back to `QuantumNous/new-api` — reduces maintenance burden and demonstrates open source good citizenship

---

## 9. Risk Summary

| Risk Area | Severity | Mitigation Status |
|-----------|----------|-------------------|
| AGPL network copyleft (New API modifications) | **HIGH** | ⚠️ Requires immediate source disclosure if modified |
| AGPL contagion to adapter services | **LOW** | ✅ HTTP boundary provides separation |
| Apache-2.0 NOTICE preservation | **MEDIUM** | ⚠️ Add to deployment checklist |
| Dependency license conflicts | **LOW** | ✅ All permissive licenses |
| Trademark violations | **LOW** | ✅ Attribution use is permitted |
| Patent retaliation (Apache-2.0) | **LOW** | ℹ️ Only triggers if company sues contributors |

---

## 10. Recommendations

1. **Establish modification freeze:** Do not modify New API until source disclosure mechanism is implemented
2. **Legal review within 2 weeks:** Schedule attorney consultation to validate AGPL compliance strategy
3. **Create compliance runbook:** Document exact steps for source archive generation, UI link placement, and version synchronization
4. **Add CI/CD check:** Automated test that fails if `vendor/new-api` diff is non-empty without corresponding public source commit
5. **Internal training:** Ensure developers understand AGPL triggers before editing New API code

---

## Appendix A: License File Locations

- `vendor/new-api/LICENSE` — AGPL-3.0 (662 lines)
- `vendor/new-api/NOTICE` — Attribution notices + AGPLv3 §7 additional terms
- `vendor/agency-orchestrator/LICENSE` — Apache-2.0 (191 lines)
- `vendor/agency-orchestrator/agency-agents/LICENSE` — MIT
- `vendor/LocalMiniDrama/LICENSE` — MIT

## Appendix B: Key AGPL Sections Reference

- **§1 (Source Code):** Defines "Corresponding Source" — all code needed to build and run the modified program
- **§2 (Basic Permissions):** Unlimited permission to run unmodified Program
- **§5 (Modified Source Versions):** Requirements when conveying modified source
- **§6 (Conveying Non-Source Forms):** Binary distribution rules (stricter than §13)
- **§13 (Remote Network Interaction):** **The network copyleft clause** — must offer source to network users
- **§7 (Additional Terms):** Permits downstream to add attribution requirements (New API uses this for frontend credits)

---

**Document prepared by:** Claude Code (Opus 5)  
**Review required by:** Legal counsel + Engineering leadership  
**Next review date:** Before any New API modification deployment
