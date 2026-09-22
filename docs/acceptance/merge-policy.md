# Code Merge Standard

## Required checks

`main` can only be updated through a pull request. A pull request must satisfy:

- `Acceptance Gate / acceptance` and `Security Gate / secret-scan` all pass;
- at least one approval is present and CODEOWNERS approval is required for protected paths;
- stale approvals are dismissed after a new push and the last push must be approved;
- all review conversations are resolved;
- history is linear;
- force pushes and deletion of `main` are disabled;
- wallet, SSO, model, pricing, permission, migration, and compliance changes link acceptance IDs and evidence.

Machine-readable policy: [`merge-policy.json`](./merge-policy.json).

## Current remote state

Repository: `https://github.com/1240052492/ZSXQ_TOKEN`

The repository is public. GitHub `main` branch protection is enabled and verified with:

- three required status checks listed above;
- one required approval and CODEOWNERS review;
- stale approval dismissal and last-push approval;
- required conversation resolution and linear history;
- force-push and branch-deletion protection;
- administrator enforcement.
