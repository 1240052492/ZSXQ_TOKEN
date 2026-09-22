# WP-00 Source Baseline

审计时间：2026-09-22 Asia/Shanghai
审计方式：GitHub REST API、公开仓库 Raw 文件、本地只读检查
状态：`blocked`

## Frozen upstream references

| 项目 | URL | 分支 | commit | 许可证 |
|---|---|---|---|---|
| New API | https://github.com/QuantumNous/new-api | `main` | `9310231b3c27fea933e939b46cf26e0ce67192e3` | AGPL-3.0 |
| LocalMiniDrama | https://github.com/1240052492/LocalMiniDrama | `main` | `adaecf71a38277126fbe1e5e0d79664300f855c1` | MIT; fork of `xuanyustudio/LocalMiniDrama` |

## Observed implementation boundaries

- New API: Go 1.25/Gin/GORM backend, React/TypeScript web frontend, PostgreSQL/SQLite/MySQL support, optional Redis. Relevant paths include auth/session, billing/quota/reservation, pricing, model metadata, channel constraints, relay and task plugins.
- LocalMiniDrama: Node.js 18+/Express backend with `better-sqlite3`, Vue 3/Vite frontend, Electron desktop package. Relevant paths include local AI configuration, direct provider clients, SQLite migrations, task processing, asset storage, upload and ZIP import/export.
- The projects do not share an identity, wallet, database schema, or service contract at these commits.

## Evidence URLs

- https://api.github.com/repos/QuantumNous/new-api
- https://api.github.com/repos/QuantumNous/new-api/branches/main
- https://api.github.com/repos/1240052492/LocalMiniDrama
- https://api.github.com/repos/1240052492/LocalMiniDrama/branches/main
- https://api.github.com/repos/QuantumNous/new-api/git/trees/main?recursive=1
- https://api.github.com/repos/1240052492/LocalMiniDrama/git/trees/main?recursive=1

## Closure blockers

1. The upstream source has not yet been imported or archived into the implementation repository.
2. Clean-environment build and startup logs have not been captured.
3. Dependency lock inventories and SPDX/CycloneDX SBOMs have not been generated from the frozen commits.
4. AGPL-3.0 obligations, New API attribution requirements, and LocalMiniDrama fork rights require a written specialist review.

This baseline supports design work and does not support `WP-00=done`, production release, or a claim that the integration is implemented.
