# CHEKMI Phase 1 — staging, backend recovery, and security foundation

## 24 October 2026 staging gate update

**Gate remains blocked.** A separate Supabase project and backend have not been provisioned. The user confirmed that staging was not provisioned, and this machine has no authorized Supabase management token, Supabase CLI, staging database connection, or backend hosting access. No remote migration, Edge deployment, staging payment, production change, or real provider call was made. The 21 October findings below are historical unless superseded here.

### What is now prepared

| Area | Verified result | Changes |
|---|---|---|
| GitHub deployment boundary | The repository's `staging` environment was absent when checked with repository-admin access; it has now been created and confirmed with an owner-required review rule. Its environment variables and secrets are both empty. A 404 from the earlier environment lookup was checked against the environment list and was genuine absence, not assumed from the status alone. | GitHub repository environment; no production deployment |
| Local target | The ignored `config/staging.json` had production Supabase and backend hosts. It was replaced locally with fail-fast placeholders from `config/staging.example.json`. It is not committed or a usable staging credential source. | Ignored local `config/staging.json` |
| Provider isolation | A staging backend in fixture mode now handles the private provider-lookup route with synthetic responses, after its internal-key check. It requires expected amount and receiving account, and does not contact a live provider. The staging Edge verifier supplies those values only in staging fixture mode. Production retains its live lookup contract. The demo labels fixture results illustrative. | `backend-server/src/routes/providerLookupRoute.ts`, `backend-server/src/edgeVerification.ts`, `backend-server/src/demoVerification.ts`, tests, generated `chekmi-verify` and `chekmi-demo` bundles |
| Staging packaging | Added a staging-only backend environment template and `package-alet.ps1 -Staging`. The new package includes the staging template, compiled backend, and source; it excludes the production-oriented Alet example, `.env`, and `node_modules`. Its SHA-256 is `ECA76D9D05E288261641F24D6904A81100359E1F04D96B8D45894791B47ED3D2`. | `backend-server/.env.staging.example`, `backend-server/scripts/package-alet.ps1`, `build/Chekmi-Staging-Backend-Safe-v2-20261024.zip` (local ignored artifact) |
| Edge deployment check | The manual staging workflow sets `CHEKMI_VERIFIER_MODE=fixtures` for staging Edge functions and now checks both verifier/evidence and demo generated bundles before deployment. | `.github/workflows/supabase-staging.yml` |

### Actual validation on 24 October

| Command or check | Result |
|---|---|
| `node scripts/check_staging_target.mjs` with current local configuration | **Exit 1 as intended:** distinct staging ref and valid staging Supabase/backend URLs are absent. This is not a pass with genuine staging configuration. |
| `node --test scripts/check_staging_target.test.mjs` | **5/5 passed**, including rejection of production project, production backend, production database, malformed URLs, and a positive synthetic staging target. |
| `flutter test --no-pub test/app_environment_test.dart` | **11/11 passed**, including Flutter rejection of production targets in nonproduction modes. |
| `npm test` in `backend-server` | **64/64 passed** with test doubles; includes staging fixture route, illustrative demo, readiness label, and the prior evidence/tenant tests. No deployed provider or Storage system was exercised. |
| `npm run build` in `backend-server` | **Passed** after correcting the new readiness test type. |
| `node backend-server/scripts/build-edge.cjs` and `node backend-server/scripts/build-demo.cjs` | **Passed**; generated verifier, receipt evidence, and demo bundles. |
| Staging backend ZIP manifest | **126 entries**; staging example present, production Alet example absent, private `.env` absent, `node_modules` absent. |
| GitHub environment API | `staging` exists with required owner review; **0 variables, 0 secrets**. No workflow was dispatched. |
| Remote migration list, migration dry run/apply, Edge readiness, Auth, Storage, two-tenant access | **Not run** because there is no separate staging project or backend. |

### Exact operator action to unblock the gate

1. Create a new Supabase project for Chekmi staging under an account authorized to provision it. Confirm any plan or resource cost in that account first. Do not import customer data. The project must have its own Auth, Postgres, Storage, project ref, database password, publishable key, service-role key, and management access token.
2. Create a separate HTTPS backend app. Deploy `build/Chekmi-Staging-Backend-Safe-v2-20261024.zip` or the same source commit using `backend-server/.env.staging.example` as the variable checklist. Set its `CHEKMI_ENV=staging`, distinct `CHEKMI_STAGING_PROJECT_REF`, staging `SUPABASE_URL`, staging `SUPABASE_SERVICE_ROLE_KEY`, `CHEKMI_VERIFIER_MODE=fixtures`, `CHEKMI_VERIFICATION_ENGINE=owned`, and a new staging-only `CHEKMI_INTERNAL_LOOKUP_KEY`. Keep the service-role key and internal key in the host's secret store. Do not copy production values or configure live provider credentials.
3. In the existing protected GitHub `staging` environment, set variables `STAGING_SUPABASE_PROJECT_REF`, `STAGING_SUPABASE_URL`, `STAGING_CHEKMI_BACKEND_URL` (HTTPS URL ending in `/api`), and `STAGING_CORS_ALLOWED_ORIGINS`. Set secrets `STAGING_SUPABASE_ACCESS_TOKEN`, `STAGING_SUPABASE_DB_PASSWORD`, `STAGING_DATABASE_URL`, `STAGING_SUPABASE_PUBLISHABLE_KEY`, `STAGING_CHEKMI_INTERNAL_LOOKUP_KEY`, and `STAGING_FIXTURE_STAFF_PASSWORD`. The internal key must match the new backend's key. Never send secret values in chat or commit them.
4. Provide access to those configured resources or confirm they are ready. Then run `node scripts/check_staging_target.mjs` using the genuine staging values. Only after it passes, run the protected `Supabase staging deployment` workflow with `apply=false`, review `supabase migration list` and `supabase db push --dry-run`, and then run with `apply=true` and synthetic seed. Validate the three Edge endpoints, private Storage, and two synthetic workspaces with the existing health/schema/isolation scripts. Record the actual results here before considering Phase 2 unblocked.

The owner review rule protects the GitHub deployment workflow. It does not substitute for a separate cloud project, backend, credentials, successful guard run, or live tenant-isolation test. **PHASE 1 STAGING GATE HAS NOT PASSED.**

### Audit status carried forward

| Requirement IDs | Current status | Why |
|---|---|---|
| A12, H20, K06 | PARTIAL | Source and GitHub deployment boundaries exist, but no second cloud project/backend or runtime separation test exists. |
| K03, K04 | NOT VERIFIED | All three Edge functions and relevant RPC migrations exist in source, but the staging project and remote migration history are unavailable. |
| K05 | NOT VERIFIED | Staging deliberately uses synthetic fixtures; authorized provider sandbox credentials have not been supplied. |
| H02, H03, H19 | NOT VERIFIED | Local tenant and permission tests pass with doubles; remote RLS, private Storage, and member revocation have not been exercised in staging. |

The last observed production readiness check on 21 October showed `chekmi-verify` ready and `chekmi-demo` and `chekmi-receipt-evidence` returning 404. No new production probe was performed in this update, and no staging endpoint exists to probe yet. Staging migration list, dry run, apply, and schema assertions are all **not run**. The only rollback needed for this update is source reversion or deleting the empty GitHub staging environment; no database or hosted application was changed.

**21 October 2026. Status: partially implemented; staging acceptance is blocked.** No production migration, Edge deployment, financial transaction, SMS, or customer-data write was performed. The distinct staging Supabase project and credentials were not available in this workspace. Source and local tests cannot prove live staging isolation, receipt Storage authorization, or restored endpoints.

## Baseline and architecture

The requested `CHEKMI_PRODUCTION_READINESS_AUDIT(10).md` was not present in the repository or searched Downloads path. The available [concise audit](../audits/CHEKMI_PRODUCTION_READINESS_AUDIT.md) was read in full. No applicable `AGENTS.md` was found in the repository. The installed skill catalog had UI/design skills but no dedicated Supabase/backend security skill relevant to this phase.

Chekmi has a Flutter client (`lib/`), a Node/TypeScript verification backend (`backend-server/`), and Supabase PostgreSQL, RLS, Storage, and Edge functions (`supabase/`). The app initializes Supabase only after `AppEnvironment.validateOrThrow()`. The `chekmi-verify`, `chekmi-demo`, and `chekmi-receipt-evidence` Edge source and `supabase/config.toml` entries already existed. The archive migration `202610200001_receipt_evidence_archive.sql` already defined a private 6 MiB JPEG/PNG bucket, restrictive client-deny Storage policy, service-only receipt RPCs, and legacy-image compatibility. None of that proves it is deployed.

## Implemented in this phase

| Area | Change | Files |
|---|---|
| Environment separation | Removed hardcoded production Supabase URL/key from development defaults. Development, staging, and production backend coordinates are explicit; nonproduction rejects the known production Supabase project and both observed production API hosts. Production requires its approved Supabase project. Preview starts without a backend. | `lib/core/config/app_environment.dart`, `config/{development,preview,staging,production}.example.json`, `.gitignore`, `scripts/start_iphone_preview.ps1`, `test/app_environment_test.dart` |
| Backend startup | Staging backend requires `CHEKMI_STAGING_PROJECT_REF`, matching `SUPABASE_URL`, and a service-role key. A production-mode process cannot silently use another project. | `backend-server/src/deploymentEnvironment.ts`, `backend-server/src/index.ts`, test |
| Staging deployment | Added a manual GitHub Actions workflow bound to the `staging` environment. It rejects production project/backend/database coordinates, lists migration history, runs a dry run, and applies migrations, Edge secrets, functions, assertions, and optional synthetic seed only when `apply` is selected. The AltStore test build now uses the staging environment and a validated staging target. | `.github/workflows/supabase-staging.yml`, `.github/workflows/ios-altstore.yml`, `scripts/check_staging_target.mjs`, test |
| Staging SQL and fixtures | Added read-only schema/RLS/Storage/RPC assertions and a second synthetic workspace fixture. Tightened the existing bootstrap so its DB host/user must identify a nonproduction project before any seed/migration write. The existing restaurant Mesob fixture remains. | `supabase/staging_schema_assertions.sql`, `supabase/staging_isolation_seed.sql`, `supabase/staging_verification.sql`, `scripts/bootstrap_staging.ps1` |
| Health | Accepts the actual ready `veritas` engine as well as `owned`; checks receipt evidence's expected unauthenticated `401`; distinguishes ready, unauthorized, missing endpoint, dependency failure, and unavailable service without logging response bodies or secrets. Supports an explicit staging target. | `scripts/check_production_health.mjs`, `scripts/health_contract.mjs`, test |
| Dependency security | Updated compatible locked production dependencies: axios 1.20.0, follow-redirects 1.16.1, proxy-addr 2.0.8, qs 6.16.1, undici 7.30.1. No major direct dependency change. `proxy-addr` is relevant because the Express server uses `trust proxy`. `axios` is declared directly but no source import was found; `follow-redirects` is its dependency. `undici` and `qs` are transitive. CI and staging deployment now fail on new production advisories. | `backend-server/package-lock.json`, `.github/workflows/{ci,supabase-staging}.yml` |
| Tenant test foundation | Added a two-synthetic-workspace Edge-handler test and a read-only staging smoke script for own/cross-workspace originals and direct anonymous Storage access. No live staging isolation result is claimed. | `backend-server/src/edgeReceiptEvidence.test.ts`, `scripts/check_staging_receipt_isolation.mjs` |

No corrective migration was created: the checked-in archive migration already contains the necessary bucket and service-only RPC model. Reconciliation against an authorized staging database must occur before changing schema. The new SQL files are **checks and synthetic seed**, not production migrations. Direct client Storage operations remain denied by the existing restrictive policy; the receipt Edge function streams an original only after a tenant-scoped service RPC checks the staff session. It does not issue signed URLs, so signed-URL expiry is not part of this transport.

## Actual verification results

| Command / environment | Result |
|---|---|
| `flutter test test/app_environment_test.dart` / local Windows | Passed: **11/11**, including rejection of both observed production API hosts. |
| `flutter test` / local Windows | Passed: **87 tests, 2 skipped** before the final added host assertion; the focused suite was rerun after that assertion. No real provider call. |
| `flutter analyze` / local Windows | Passed after the final Dart edits: no issues. |
| `npm test` / local backend | Passed: **61/61**, including two-workspace denial, retry, bad-session, and receipt-storage doubles. The final focused receipt suite passed **5/5**, including cross-workspace upload denial and unsupported overwrite/delete methods. |
| `npm run build` / local backend | Passed. |
| `node --test scripts/check_staging_target.test.mjs scripts/health_contract.test.mjs` / local | Passed: **7/7**, including the actual local staging file's production API hostname and malformed/credentialed URLs. |
| `node backend-server/scripts/build-edge.cjs` + `git diff --exit-code -- supabase/functions/...` / local | Passed: generated verifier and receipt Edge bundles match checked-in sources. No deployment. |
| PowerShell parser on `scripts/bootstrap_staging.ps1`; `node --check` on health/isolation scripts | Passed. No SQL executed. |
| PyYAML parse of both changed GitHub Actions workflows | Passed: syntax valid. Neither workflow was executed. |
| `npm audit --omit=dev --audit-level=moderate` / current lockfile | Passed: **0 production advisories**; before patch: 1 critical, 3 high, 1 moderate. Full audit still reports four high findings in development tooling (`brace-expansion`, `braces`, `chokidar`, `nodemon`); these are not in the production-only tree and need a separate CI-tooling update. |
| Updated read-only production health probe / 21 Oct | Exit 1: `chekmi-verify` 200/ready with `veritas`; `chekmi-receipt-evidence` 404; `chekmi-demo` 404. Legal versions, two invalid-session RPC rejection checks, and four legal pages passed. This was a read-only observation, **not a production change**. |
| Staging migration history, Edge readiness, SQL assertions, two-tenant Storage, fixture login, signed release | **Not run**: no distinct staging project credentials/CLI/database connection or synthetic tickets were available. |

The production health failure is now accurate: it is caused by two missing endpoints, not an obsolete `owned` expectation. It does not mean a real bank verification was tested.

## Staging provisioning and deployment runbook

1. Provision a **new Supabase project** with its own Auth, database, Storage, project ref, publishable key, service-role key, and access token. Do not clone customer records or reuse production credentials. Provision a separate HTTPS backend and nonproduction provider/test credentials. Set its backend `CHEKMI_ENV=staging`, `CHEKMI_STAGING_PROJECT_REF`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `CHEKMI_INTERNAL_LOOKUP_KEY`, and its own verifier credentials. The backend startup guard must pass before serving.
2. In GitHub's protected **staging** environment, set variables `STAGING_SUPABASE_PROJECT_REF`, `STAGING_SUPABASE_URL`, `STAGING_CHEKMI_BACKEND_URL`, `STAGING_CORS_ALLOWED_ORIGINS`; set secrets `STAGING_SUPABASE_ACCESS_TOKEN`, `STAGING_SUPABASE_DB_PASSWORD`, `STAGING_DATABASE_URL`, `STAGING_SUPABASE_PUBLISHABLE_KEY`, `STAGING_CHEKMI_INTERNAL_LOOKUP_KEY`, and `STAGING_FIXTURE_STAFF_PASSWORD`. The backend and Edge function must receive the **same** internal lookup key. Store secret values only in the provider's secret store. No values belong in this report or a committed config.
3. Review staging's migration history against `supabase/migrations/`, especially `202610160001`, `202610180001`, and `202610200001`. Run the manual **Supabase staging deployment** workflow once with `apply=false`; inspect its migration list and dry run. After review, run `apply=true` and optionally `seed_synthetic=true`. That path deploys all three existing function names and executes the schema/security assertions. A backend deployment is separate and must be completed before `chekmi-verify` and `chekmi-demo` can report ready.
4. Fill ignored `config/staging.json` from `config/staging.example.json` with the new staging-only values. The local file was reset to placeholders on 24 October, so it cannot run until real staging values are supplied. The Flutter guard rejects the known production project. For local development, use `config/development.example.json` with local Supabase; for offline visual preview, use `CHEKMI_ENV=preview` and `CHEKMI_UI_PREVIEW=true`.
5. Run `CHEKMI_ENV=staging CHEKMI_SUPABASE_URL=<staging URL> CHEKMI_SUPABASE_PUBLISHABLE_KEY=<staging publishable key> node scripts/check_production_health.mjs`. An unauthenticated receipt GET must yield the expected application `401 SESSION_REQUIRED`, not a platform 404. Run `supabase/staging_schema_assertions.sql` read-only using `psql` against the distinct staging database. After creating **synthetic verified fixture tickets and originals** for Mesob A and Isolation B, run `scripts/check_staging_receipt_isolation.mjs` with short-lived fixture staff tokens, ticket IDs, and B's object key. It performs no provider lookup or financial write.

The local `scripts/bootstrap_staging.ps1` is another staging-only setup route. It now requires `-ExpectedProjectRef`, `-ExpectedDatabaseHost`, `-DatabaseUrl`, and environment variable `STAGING_FIXTURE_STAFF_PASSWORD`; it refuses URLs/usernames identifying production before writing. Do not use it on a populated project without first reviewing migration and seed impact.

## Remaining blockers and security limits

1. **No verified separate staging project.** No staging URL, database history, bucket, Auth users, function deployment, or backend secret set was accessible. The workflow is prepared but unrun. Phase 1 acceptance criteria 1, 3, 4, 5, and 6 remain unverified. This is a blocker, not a success claim.
2. **Live tenant isolation remains unproven.** SQL/source and local doubles deny cross-tenant original reads; live A/B GET and direct Storage checks have not run. The Storage policy structurally denies anon/authenticated direct GET/POST/PUT/DELETE, but deployment and adversarial runtime outcomes need confirmation. The Edge transport does not use signed URLs. Do not claim upload/overwrite/delete isolation is proven until staging tests execute.
3. **Production missing endpoints remain 404.** The staging workflow will deploy them only after staging is provisioned and explicitly applied. Production deployment is outside this phase.
4. **Dependency runtime reachability was reviewed, not exhaustively exploited.** The patched production lockfile has zero advisories. Full dependency audit still has four high development-tool advisories; pinning/updating these should be handled without destabilizing build tooling.
5. **No provider transaction or physical-device test occurred.** Existing restaurant/verification code passed local tests, but end-to-end staging bank/evidence behavior remains outside the evidence available today.

## Rollback and recovery

The source changes can be reverted by file or commit. Revert the environment guards only after replacing them with an equally strict project check; otherwise an old staging build can reconnect to production. `npm ci` from a prior lockfile restores prior package versions. No database rollback is needed now because **nothing was deployed**. If a future staging application of migrations fails, stop writes, inspect `supabase migration list` and the staging DB backup, fix with an additive migration, and redeploy only the affected staging function from a known commit. Do not roll back immutable financial/evidence history by deleting rows. Production rollback is not applicable to this phase.

**Phase 1 release gate:** provision and verify isolated staging, deploy/reconcile the two missing services there, execute the schema and two-workspace runtime tests, then review the recorded results. Until then, the audit's public-release recommendation is unchanged.
