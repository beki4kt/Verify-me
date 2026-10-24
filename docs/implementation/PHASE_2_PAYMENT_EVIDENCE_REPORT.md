# Chekmi Phase 2 — payment integrity and receipt evidence

> **Owner decision, 24 October 2026:** The separate-staging gate described below has been superseded for the prelaunch pilot. Use the current project and `MESOB-DEMO` under [MESOB_PRELAUNCH_PILOT.md](MESOB_PRELAUNCH_PILOT.md). This changes the test environment decision; it does not upgrade any unverified payment or evidence requirement. No live Phase 2 test was completed by this decision.

> **Read-only current-project probe, 24 October:** `chekmi-verify` returned 200/ready with engine `veritas`; `chekmi-demo` and `chekmi-receipt-evidence` returned 404. The latter two remain deployment gaps. The prepared source verifier reports `owned`, so a blanket deploy of all three functions would change the working verifier engine and is not authorized by this pilot plan.

**Preflight status, 24 October 2026: blocked by the Phase 1 staging gate. Phase 2 implementation and financial integration testing have not begun.** No payment, SMS, migration, Storage write, or production deployment was performed. The current best iPhone source/build remains commit `f2e199b`.

The owner confirmed on 24 October that a separate staging Supabase project and backend have **not** been provisioned.

## Gate evidence

| Check | Observed result | Consequence |
|---|---|---|
| Phase 1 foundation report | `docs/implementation/PHASE_1_FOUNDATION_REPORT.md` says isolated staging, deployment, schema reconciliation, and two-tenant runtime checks were unverified. | Phase 1 acceptance cannot be inferred from local tests. |
| Local ignored staging config | `config/staging.json` exists, but a read-only host comparison found that its Supabase and backend hosts are both the known production hosts. No URL or key was printed. | It cannot be used for safe Phase 2 tests. |
| Staging target guard | `node scripts/check_staging_target.mjs` exited 1: no valid distinct project ref, Supabase URL, or backend URL was present in the command environment. | A functional staging build or deployment has no validated target. |
| GitHub staging environment | On 24 October, repository-admin access confirmed the environment was absent, then created `staging` with required owner review. It currently has zero variables and zero secrets. | Required staging credentials are still unavailable; no configured cloud target is proven. |
| Live schema, endpoints, tenant isolation | No authorized staging database connection or deployed staging endpoint was available to inspect. | Migration state, private evidence retrieval, and cross-workspace denial remain unverified. |

The requested `CHEKMI_PRODUCTION_READINESS_AUDIT(10).md` was not found in the repository or the searched workspace. The available baseline is `docs/audits/CHEKMI_PRODUCTION_READINESS_AUDIT.md`, which retains D01–D30 and E01–E30 as Partial, Missing, or Not Verified according to its status index. **No D/E status is upgraded here.**

## Required to open Phase 2

1. Provision a separate Supabase project, database, Auth, private Storage, and backend with synthetic tenants and authorized provider sandbox credentials. Do not reuse production hosts or customer records.
2. Configure the protected GitHub `staging` environment with `STAGING_SUPABASE_PROJECT_REF`, `STAGING_SUPABASE_URL`, `STAGING_CHEKMI_BACKEND_URL`, `STAGING_SUPABASE_PUBLISHABLE_KEY`, and the deployment/database secrets listed in the Phase 1 report. Do not place secret values in source control or this report.
3. Run `node scripts/check_staging_target.mjs` with the configured staging values and record a passing result. Reconcile remote migration history, then run the existing staging workflow's dry run before applying additive schema and deploying staging Edge functions.
4. Verify staging `chekmi-verify`, `chekmi-demo`, and `chekmi-receipt-evidence` readiness; run the read-only schema assertions and two synthetic workspace receipt-access checks from Phase 1. Record actual results and confirm staging cannot write to production.
5. Only then trace the deployed verification → commit → ledger → evidence → history path, implement identified gaps, and execute Phase 2 financial and image tests with authorized sandbox data.

## Test record and limits

- `node scripts/check_staging_target.mjs` — local Windows, exit 1, invalid/missing staging target variables.
- Read-only classification of `config/staging.json` — both configured hosts match known production hosts; credential values were not displayed.
- GitHub staging environment metadata — `staging` now exists with required owner review, zero variables, and zero secrets; no values retrieved.
- No provider, database, Storage, migration, or financial reconciliation test was run. Source files and existing local tests cannot establish deployed payment correctness.

## Migration and recovery

No migration or backend change was made in this preflight, so no rollback is needed. Keep `f2e199b` as the current iPhone baseline. When Phase 2 opens, use additive migrations and preserve immutable financial/evidence records; document each staging migration and its recovery plan before any production rollout.
