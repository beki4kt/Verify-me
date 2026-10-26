# Chekmi production-readiness audit — concise edition

**Audit basis:** Repository inspection and safe checks performed 20–21 October 2026 on branch `sql/mesob-catchup-20261020`. This condenses the earlier audit; it is **not a new production test**. No payment, SMS, migration, deployment, or customer-data write was performed.

## Decision

**Ready for controlled internal testing; not ready for public iOS or Android release.** The app has a real Flutter client, a shared verification engine, restaurant workflows, Supabase security/migration code, and meaningful local tests. Their presence does not establish that the deployed system or physical devices work end to end.

The most urgent finding is that the configured Supabase project returned **404** for `chekmi-receipt-evidence` and `chekmi-demo` on 20 October. `chekmi-verify` returned **200/readiness**, but no real provider transaction was run. Invalid-session probes showed that `my_owner_registration` and `get_verified_receipt_detail` RPCs exist and reject unauthenticated calls; they did not prove a complete migration or authorized workflow. Test and production-labelled builds point to the **same Supabase project** ([environment config](../../lib/core/config/app_environment.dart#L47), [Mesob release note](../mesob-iphone-test-release-2026-10-20.md#L3)).

Native owner registration remains **email/password with email confirmation** ([registration screen](../../lib/business_registration_screen.dart#L126), [owner SQL](../../supabase/migrations/202610180001_owner_registration.sql#L83)). Five-category/subtype onboarding, phone-first owner login, and Events are **interactive browser-preview features**, not native production features. Restaurant and generic workspace paths exist, but their live financial and historical-data behavior still needs staged/device proof.

## Evidence and limitations

| Area | What was actually established |
|---|---|
| Local tests | `flutter test`: **85 passed, 2 skipped**; opt-in iPhone layout suite: **8 passed**; backend `npm test`: **59 passed**; `flutter analyze` and backend `npm run build` passed. Backend tests use doubles for provider, duplicate, retry, tenant, and evidence behavior. |
| Browser previews | Both preview checkers passed at 320, 375, 390, and 430 px. Their authentication, payments, Events, and receipt examples are illustrative. |
| Android | Local debug APK built after selecting Android Studio's JDK; `aapt` showed package `com.chekmi.app`, min SDK 24, target SDK **36**. An [older Android CI run](https://github.com/beki4kt/Verify-me/actions/runs/35881691381) built/uploaded a signed AAB. No current signed AAB or physical-device journey was checked. |
| iOS | An older CI run produced an **unsigned** iPhone IPA. No current signed App Store archive or physical-device run was checked. Windows cannot build an iOS release locally. |
| Live read-only probes | Verifier readiness `200` (`veritas`); demo `404`; receipt evidence `404`; owner-registration RPC `401/42501`; verified-receipt-detail RPC `403/28000`. Readiness and authorization rejection are narrower evidence than successful use. |
| Operations/security | `node scripts/check_production_health.mjs` exited **1**: demo is 404 and its verifier check expects `owned` while live readiness reports `veritas`. `npm audit --omit=dev` reported **1 critical, 3 high, 1 moderate** production-package advisories; reachability was not established. Backup/restore outcomes and store-console entries were not available. |

The architecture is Flutter/Dart (`lib/`), Node/TypeScript (`backend-server/`), Supabase PostgreSQL/RPC/RLS and Edge functions (`supabase/`), plus separate HTML/JS previews (`preview/`). The app uses Supabase Auth for owners, a custom workspace-scoped staff session, and legacy `receipt_images` with a proposed private `receipt-evidence` Storage bucket. The archive design is in [migration 202610200001](../../supabase/migrations/202610200001_receipt_evidence_archive.sql#L1) and [Edge transport](../../backend-server/src/edgeReceiptEvidence.ts#L100), but its live transport endpoint is absent.

## Release blockers and financial risks

| Priority | Finding and evidence | Why it matters |
|---|---|---|
| **P0** | Receipt-evidence Edge endpoint `404`; [mobile client](../../lib/api_service.dart#L598) calls it. | A verified payment can lack retrievable original-image evidence; retry cannot complete while the endpoint is absent. Bank verification must remain independent of upload failure. |
| **P0** | Provider→commit→ledger, duplicate/concurrent requests, wrong receiving account, timeout, and tenant isolation are tested locally, not against an isolated deployed system ([verification tests](../../backend-server/src/edgeVerification.test.ts), [commit SQL](../../supabase/migrations/202610160001_inclusive_workspaces.sql#L521)). | False confirmation, double counting, unauthorized completion or cross-workspace exposure cannot yet be ruled out for the deployed system. |
| **P0** | Test and production configurations share the same Supabase project. | Testing could affect production records; it also prevents safe adversarial tests with two tenants. |
| **P0** | Public account/subscription contract is unfinished: email-first native owner login; phone-first preview only; owner deletion/recovery and abuse controls unproven; plan entitlement enforcement and expired-history access need work ([owner flow](../../lib/launch_experience.dart#L352), [subscription gate](../../supabase/migrations/202608120004_subscription_lifecycle.sql#L116)). | Account lockout, wrong access, unavailable history, or inaccurate paid-plan claims. |
| **P0** | Current signed releases, physical-device QA, reviewer backend/access, billing classification, provider authorization, privacy/Data Safety entries, and backup restore are not fully evidenced. | Store rejection or unsafe support/incident response. The older Android AAB proves an earlier build, not this release. |
| **P1** | The live demo remains 404 and health monitoring expects the wrong verifier engine ([health checker](../../scripts/check_production_health.mjs#L20)). | Preview/reviewer access fails and monitoring raises a misleading verifier failure. |
| **P1** | No explicit bank reversal/refund adjustment path was found; expired subscriptions appear to block all staff RPC reads, including history ([subscription gate](../../supabase/migrations/202608120004_subscription_lifecycle.sql#L116)). | Net-revenue claims and customer audit access need a defined policy. |
| **P1** | Unencrypted Hive onboarding draft contains owner contact and receiving-account details, though password is excluded ([draft write](../../lib/business_registration_screen.dart#L65), [Hive box](../../lib/offline_storage.dart#L117)); five backend production dependencies have advisories. | Device-at-rest privacy and server dependency exposure require review. |

The current Android debug artifact targets API 36, matching the [Google Play target-API rule](https://developer.android.com/google/play/requirements/target-sdk) checked 20 October 2026. Apple requires an iOS 26 SDK build for submissions since April 2026 ([official requirement](https://developer.apple.com/news/upcoming-requirements/?id=02212025a)); the actual signed iOS archive was not available for inspection. Store billing classification remains conditional: compare Chekmi's exact B2B/Solo sales model with [Apple's payment rules](https://developer.apple.com/app-store/review/guidelines/) and [Google's Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818). Legal classification in Ethiopia requires qualified counsel; the [Personal Data Protection Proclamation](https://justice.gov.et/en/law/personal-data-protection-proclamation/) is relevant but does not, by itself, settle Chekmi's obligations.

## Complete requirement status index

This compact index preserves the **individual status of all 269 IDs** from the full audit specification. `IMPLEMENTED & TESTED` means behavior-specific successful local/runtime evidence; `PARTIAL` means an implementation gap; `MISSING` means no functional path found; `NOT VERIFIED` means evidence/access was insufficient. IDs retain the original A–L requirement names. A passing build, a preview screen, or source SQL alone never establishes a production payment workflow.

| Category | IMPLEMENTED & TESTED | PARTIAL | MISSING | NOT VERIFIED |
|---|---|---|---|---|
| **A Architecture** | A02 | A01,A03,A04,A05,A06,A07,A08,A09,A10,A11,A13,A14,A15 | A12 | — |
| **B Onboarding** | B03 | B01,B02,B04,B05,B06,B10,B11,B12,B13,B14,B15,B17,B18 | B07,B08,B09 | B16 |
| **C Authentication** | — | C01,C02,C03,C04,C07,C09,C10,C11,C12,C13,C14,C16,C17,C20,C21 | C05,C06,C08,C18,C19,C22 | C15 |
| **D Verification** | — | D02,D03,D04,D05,D06,D07,D08,D09,D10,D11,D12,D13,D14,D15,D16,D17,D18,D19,D20,D21,D22,D23,D24,D25,D26,D27,D28,D29 | D30 | D01 |
| **E Receipts** | — | E03,E04,E05,E06,E07,E08,E09,E10,E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,E21,E22,E23,E24,E25,E26,E27,E28,E29 | — | E01,E02,E30 |
| **F Workspaces** | — | F01,F03,F04,F05,F06,F07,F08,F09,F10,F12,F13,F14,F15,F16,F23,F25,F26,F27,F28,F29,F30,F31,F32,F33,F34 | F02,F11,F17,F18,F19,F20,F21,F22,F24 | — |
| **G Billing** | G01 | G02,G03,G04,G05,G06,G07,G08,G09,G10,G12,G13,G14,G15,G16,G19,G20 | G11 | G17,G18 |
| **H Security** | H12 | H01,H02,H03,H04,H05,H06,H07,H08,H09,H10,H11,H13,H14,H15,H16,H17,H18,H19 | H20 | — |
| **I iOS** | — | I01,I02,I03,I04,I05,I06,I10,I11,I12,I13,I14,I15,I17,I19,I20,I22 | — | I07,I08,I09,I16,I18,I21 |
| **J Android** | J01 | J02,J03,J15,J16,J17,J19 | — | J04,J05,J06,J07,J08,J09,J10,J11,J12,J13,J14,J18,J20 |
| **K Operations** | — | K01,K02,K03,K04,K07,K08,K09,K13,K14,K15,K16,K17,K18,K19,K20 | K06,K12 | K05,K10,K11 |
| **L Compliance** | — | L01,L02,L03,L04,L05,L08,L13,L15,L16,L17 | — | L06,L07,L09,L10,L11,L12,L14,L18 |

**Totals:** 269 requirements: **5 IMPLEMENTED & TESTED · 202 PARTIAL · 24 MISSING · 38 NOT VERIFIED**. This is a classification count, not a readiness percentage. Events receipt categorization/stations/reporting remain missing; **ticketing and admission are intentionally outside scope**. Shop/service/personal features are partial where a typed reference or generic UI exists without a proven full business flow.

## What to do next

1. **Create isolated staging first (P0).** Separate Supabase project, keys, Mesob fixtures, build definitions, and provider test credentials. Acceptance: staging actions cannot write the production project.
2. **Reconcile schema and restore missing services (P0).** Check migration history and actual RLS/storage policies; deploy/test `chekmi-receipt-evidence` and `chekmi-demo` in staging, then use a gated production rollout. Acceptance: authorized upload/download and legacy-image read work; unauthorized tenant cannot access either.
3. **Prove financial integrity (P0).** With authorized provider test data, exercise valid/invalid/duplicate/concurrent/timeout/wrong-destination receipts across claimed providers; reconcile immutable verification evidence, payment, ledger, amount, timestamp, and image checksum. Test retry without double credit.
4. **Choose a truthful first-release scope and finish access/billing (P0).** Either implement native subtype/Events/phone-first securely, or keep them unadvertised preview concepts. Test owner registration, recovery, deletion, staff revocation, plan limits, activation and expired-history access. Settle Apple/Google billing and provider contracts before selling.
5. **Complete release operations (P0/P1).** Current signed IPA/AAB, physical iPhone/Android matrix, privacy/Data Safety declarations, reviewer account, monitored health checks, dependency triage, and a verified encrypted backup restore. Do not treat the current demo 404 or health-script false failure as resolved.

**Not verified in the audit:** a real provider transaction; production database/storage policy inventory; physical-camera/picker/session/background/retry/accessibility behavior on iOS or Android; current signed release artifacts; backup restore; store-console declarations; provider contractual authority; and regulatory classification. These require staging, devices, operator/store access, or professional review. The report's recommendation remains **controlled internal testing only** until the P0 gates have recorded evidence.

## Phase 1 addendum — 21 October 2026

[Foundation implementation report](../implementation/PHASE_1_FOUNDATION_REPORT.md). This addendum records new local evidence without treating an unprovisioned staging environment as deployed. The historical status index above is retained.

| IDs | Current status | New evidence and remaining condition |
|---|---|---|
| A11, A12, H20 | PARTIAL, MISSING, MISSING | Client, backend, test-build, and staging-deploy guards now reject the known production project; the ignored local staging config still contains production coordinates, and no distinct staging project was available. Isolation is not yet proven. |
| H03, H09, H12, H18 | PARTIAL, PARTIAL, IMPLEMENTED & TESTED, PARTIAL | Archive SQL and local tests cover client-deny Storage/service-role transport and image bounds; 61 backend tests pass. Live RLS/Storage checks remain pending. Production-package audit is now 0 advisories; four high dev-tool advisories remain. |
| K03, K04, K06 | PARTIAL, PARTIAL, MISSING | Manual staging deployment workflow, schema assertions, and synthetic second workspace are prepared but unrun. Current production receipt-evidence and demo endpoints still return 404. |
| K07, K08, K09, K14 | PARTIAL, PARTIAL, PARTIAL, PARTIAL | Health monitor now accepts the observed `veritas` engine and differentiates two 404 endpoints; backend latency/error monitoring and deployed pipeline outcomes remain unverified. |
