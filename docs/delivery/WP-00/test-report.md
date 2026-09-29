# WP-00 Test Report

Date: 2026-09-22 Asia/Shanghai
Status: `blocked`
Acceptance: `M01`

## Executed checks

| Check | Result | Evidence |
|---|---|---|
| Acceptance matrix and work-package JSON | PASS | `python scripts/validate_acceptance.py` -> `Acceptance matrix valid: 25 items; gate_mode=baseline` |
| License gate pending behavior | PASS (blocking) | `python scripts/check_license.py` returns exit code 1 while review status is pending |
| Diff whitespace | PASS | `git diff --check` |
| Upstream baseline | PARTIAL | `source-baseline.md` and `commit-manifest.json` contain frozen public refs |
| Clean build and startup | NOT RUN | Source is not archived in this repository |
| SBOM generation | NOT RUN | Frozen source dependencies are not yet archived |
| Runtime identity/wallet/provider audit | PARTIAL | Static upstream audit only; no integrated runtime exists |

## Blocking findings

- AGPL-3.0 and LocalMiniDrama fork-rights review is pending.
- Frozen source has not been imported or archived in `ZSXQ_TOKEN`.
- Clean-environment build logs, lockfile hashes and SBOM are missing.
- Static audit confirms LocalMiniDrama has local JWT/configuration, SQLite, direct provider clients, task workers and local asset paths that must be replaced or isolated.

M01 must remain `planned` or `blocked`; this report does not support `passed`, production release, or implementation completion.
