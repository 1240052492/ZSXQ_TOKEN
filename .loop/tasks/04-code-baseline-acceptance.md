# LOOP-BASELINE-01 Current code baseline acceptance

- **Objective**: inventory and validate the current uncommitted repository state, then create a clearly labeled checkpoint commit that becomes the immutable input for LOOP-ENV-01.
- **Owner**: coordinator.
- **Execution order**: run sequentially before resuming LOOP-ENV-01; do not run in parallel with deployment, Lisa changes, or another writer in this workspace.
- **Scope**: file inventory, diff classification, Node 22/Python 3 toolchain capture, local tests, lint, diff validation, secret and prohibited-capability scan, evidence report, and checkpoint commit.
- **Out of scope**: Lisa SSH changes, Docker image transfer, DNS/TLS/Nginx, service startup, real upstream model calls, production release, and unrelated refactors.
- **Allowed repository files**: .loop/evidence/, docs/delivery/, STATE.md, and this task file; the checkpoint commit may include already-present product changes only after the declared review passes.
- **effective_max_loops**: 5.
- **Acceptance IDs**: B01-B07.
- **Test command**: npm test.
- **Lint command**: npm run loop:lint and git diff --check.
- **Required evidence**: baseline commit, pre-commit tree status, changed-file classification, tool versions, test/lint exit codes, security scan result, and unresolved blockers.
- **Checkpoint naming**: use a non-release message such as chore(loop): checkpoint current integration baseline; this commit is not deployment or production acceptance.
- **Hard exit**: all declared checks return 0, no new secret or prohibited-capability finding is unresolved, an independent review accepts the file inventory, and the checkpoint commit hash is recorded.
- **Stop conditions**: missing Orca runtime for required coordination, failed test/lint after 5 loops, ambiguous ownership of existing changes, sensitive-data exposure, protected-branch access, or any need for infrastructure modification.
- **Next task**: resume LOOP-ENV-01 from the recorded checkpoint commit only after its existing deployment and acceptance reviews are settled.
