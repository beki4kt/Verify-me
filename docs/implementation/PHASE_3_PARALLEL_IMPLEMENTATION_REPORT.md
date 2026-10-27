# Chekmi Phase 3 parallel implementation

**Date:** 27 October 2026

**Branch:** `feature/phase3-auth-registration`, based on `a348a89` (`phase2/staging-gate-20261024`)
**Outcome:** Substantial local implementation; **Phase 3 is not accepted for live use**. The shared Supabase project was not changed.

## Boundary and existing architecture

The Flutter application already had a dark native entry flow, legacy staff authentication, email/password Supabase owner authentication, server RPCs for staff management, capability-based workspace navigation, a real Basic/Pro catalog, pending subscription registration, support cases, and deletion-request entry points. The existing owner registration RPC only accepted confirmed email identities. The application also stored contact and receiving-account fields in an ordinary Hive onboarding draft. A separate developer owns the Node relay, TLS, provider testing, and Phase 2 financial acceptance.

This branch changes Flutter entry, owner identity, registration recovery, and prepared owner-only SQL. It does **not** change the provider verifier, financial commit functions, receipt evidence transport, relay deployment, Plesk/TLS, or the pending `202610260002_explicit_future_tips.sql` migration. The untracked `PHASE_2_COMPLETION_ASSESSMENT.md` was left untouched.

## What is implemented locally

| Area | Result | Live status |
|---|---|---|
| Entry routing | A centralized startup decision waits for Supabase owner state and checks the server owner-session result before opening a workspace. Expired staff sessions are rejected locally. | Local tests pass; device restart and revocation still require integration tests. |
| Connect Workspace | Native code-only first step, normalized workspace code, generic failure copy, and existing staff authentication after lookup. No client role picker. The direct table fallback was removed. | Lookup RPC behavior, enumeration controls, and remote rate limiting are **not verified**. |
| Phone owner identity | Ethiopian number normalization, phone/password sign-up and sign-in through Supabase Auth, six-digit SMS OTP confirmation, native phone form, loading and error states. Existing email sign-in remains available. | Fail-closed flags keep live phone Auth off until provider/SMS and migration acceptance. No real SMS was sent. |
| Registration | Existing business/plan flow feeds a prepared, server-authorized phone-or-email owner RPC. A lost create response is recovered by reading the existing registration rather than issuing another create. Creation remains `pending_activation`; no payment is represented as complete. | Migration is prepared only; shared-project creation was not exercised. |
| Archive access after expiry | Prepared owner-only, read-only SQL list/detail RPCs and a native historical receipt screen. It never fabricates an original image. Paid verification remains separately gated. | Backend-ready flag is off; cross-tenant and expired-plan tests need a reviewed DB fixture. |
| Local privacy | Onboarding draft now retains setup choices only, excluding name, phone, email, receiving account, password, and OTP. Existing drafts are sanitized and the Hive box compacted. | Local tests pass. Hive/OS backup secure erasure is not proven; the legacy quarantined payment queue still requires a separate retention review. |
| Member management | Existing owner-facing screen and service RPCs are retained; session expiry handling is tightened. | Server capability, revocation, and tenant isolation behavior were not newly tested against the shared project. |
| Recovery/deletion | Existing email recovery, support-case, staff deletion, and business deletion-request paths are retained. Lost-phone UI points to support rather than an insecure SMS-only bypass. | Phone-change proofing, support identity checks, deletion retention policy, and live RPC behavior remain unverified. |

Security-sensitive switches in `lib/core/config/app_variant.dart` default to false. Phone owner Auth needs both `CHEKMI_PHONE_OWNER_AUTH` and `CHEKMI_PHONE_OWNER_BACKEND_READY`; owner history needs `CHEKMI_OWNER_ARCHIVE_BACKEND_READY`; self-registration needs `CHEKMI_SELF_REGISTRATION_ENABLED`. Preview mode cannot enable them. These switches are release controls, **not** a substitute for server authorization.

## Prepared migrations — not applied

1. `supabase/migrations/202610270001_phone_owner_registration.sql` extends owner registration and owner session creation for a Supabase-confirmed phone identity while preserving confirmed-email owners. It locks the Auth identity for retry serialization, returns an existing registration on replay, creates a pending workspace, owner membership, profile, receiving-account configuration, and audit event. The client cannot submit its own role.
2. `supabase/migrations/202610270002_owner_archive_access.sql` adds authenticated owner-scoped read-only receipt list/detail RPCs for historical access when paid verification is unavailable. Original image delivery still requires the separately authorized receipt service.

Both need SQL review and safe database acceptance. The linked CLI dry run succeeded and showed **three** pending migrations: the pre-existing Phase 2 future-tip migration plus these two Phase 3 migrations. Ordinary `db push` would include all three; do not run it as a Phase 3-only deployment. No migration was applied and no shared-project row was changed.

## Files and native screens

Modified: `lib/api_service.dart`, `lib/business_registration_screen.dart`, `lib/core/config/app_variant.dart`, `lib/core/models/ethiopian_phone.dart`, `lib/core/session/session_controller.dart`, `lib/iphone/entry_auth_flow.dart`, `lib/launch_experience.dart`, `lib/main.dart`, `lib/offline_storage.dart`, and associated tests.

Added: `lib/core/models/workspace_code.dart`, `lib/core/services/owner_registration_recovery.dart`, `lib/core/session/entry_route.dart`, `lib/owner_historical_receipts_screen.dart`, two prepared SQL migrations, and focused tests. Native entry screens covered are welcome/startup routing, workspace-code connection, staff sign-in, owner phone or legacy email sign-in, business registration with OTP confirmation, activation status, and owner historical receipts. The approved Chekmi theme and logo remain in place.

## Actual test results

| Command / check | Environment | Result |
|---|---|---|
| `flutter test --no-pub --reporter expanded` | Local Windows Flutter | **Pass: 107 tests, 2 skipped.** An earlier run exposed a 19 px narrow-screen overflow; the owner sign-in scroll layout was corrected and the full suite then passed. |
| `flutter analyze --no-pub` | Local Windows Flutter | **Pass: no issues found.** |
| `npm test` in `backend-server` | Local Node | **Pass: 76/76.** No Phase 2 backend code changed. |
| `npx tsc --noEmit` in `backend-server` | Local Node | **Pass.** |
| `git diff --check` | Local Git | **Pass**, with Windows line-ending notices only. |
| Supabase linked migration dry run | CLI, read-only migration planning | **Pass**; reports the three pending files described above. |
| Shared-project Auth, RPC, RLS, SMS, subscriptions, staff revocation | Shared prelaunch Supabase | **Not run**: would require approved configuration, migration, or write fixtures. |
| Physical iPhone/Android restart, keyboard, SMS and recovery | Devices | **Not run**. |

Local tests verify state transitions, code/phone normalization, duplicate-response recovery, draft minimization, owner history presentation, and narrow 320 px layouts. They do not prove deployed authentication, actual SMS delivery, SQL authorization, or financial behavior.

## Requirement status update

Statuses use the audit's exact four labels. `IMPLEMENTED & TESTED` here denotes local behavior only where explicitly stated.

| Audit area / IDs | Status | Evidence and remaining gap |
|---|---|---|
| B03–B04 entry navigation and B18 form behavior | PARTIAL | Native flows and local UI tests pass; physical-device acceptance remains. |
| B14 interrupted registration | PARTIAL | Nonsensitive selections resume; sensitive form data is deliberately re-entered. |
| C01 workspace-code-first UI | IMPLEMENTED & TESTED | Native code-only form and local routing tests. Backend acceptance separate. |
| C02–C03 code validation and abuse protection | PARTIAL | Normalization and client validation tested; lookup RPC rate limits/enumeration not proved. |
| C04, C12–C14 membership and server privilege | PARTIAL | Existing server RPC/capability architecture retained; no shared-project adversarial test. |
| C05–C08 phone login, ownership, OTP | PARTIAL | Supabase integration and native UI exist behind flags; Auth provider, SMS, expiry and resend acceptance unavailable. |
| C09–C11 recovery and legacy owners/staff | PARTIAL | Legacy paths retained; live regression and lost-phone process not accepted. |
| C15–C17 session restoration, logout, revocation | PARTIAL | Local expiry and entry routing tested; real restart and remote revocation not proved. |
| C19–C22 phone change, deletion, creation abuse, lost-phone recovery | PARTIAL | Some existing request/support paths; identity proof, retention and abuse controls need policy and live tests. |
| G03–G06 selection, pending state, activation | PARTIAL | Real plan selections and pending status retained; migration not applied and no billing activation acceptance. |
| G07–G14 expiry, limits, historical access, entitlements | PARTIAL | Existing server checks plus prepared owner archive RPC; live policy and isolation tests pending. |
| H05, H07, H19 client role, credentials, revocation | PARTIAL | No client role grant; sensitive draft minimization and local session expiry tested; server adversarial tests pending. |

No Phase 3 requirement involving live Supabase identity, staff revocation, tenant isolation, billing approval, or account deletion is claimed `IMPLEMENTED & TESTED` from a Flutter unit test alone.

## Co-developer integration contract

- Staff login continues to call the existing workspace lookup and session RPCs. A code is an identifier, not authorization. Verification endpoints must continue to enforce the server-issued staff token, workspace membership, capabilities, subscription, and current revocation status.
- The Phase 3 owner uses Supabase Auth session for owner-only registration/archive RPCs. Financial verification still uses the existing backend staff-session contract. Do not replace provider response fields or receipt evidence identifiers to accommodate this work.
- New owner registration returns `pending_activation`; only an authorized billing/approval source can activate it. `pro/active` on Mesob is a test state, not proof of subscription payment.
- Owner archive RPCs expose metadata only. Original image access must be checked by the receipt service and never exposed through a public Storage URL.
- After relay TLS is restored, test an owner and two synthetic workspaces: staff revocation, wrong-workspace token, expired plan with historical reads but no new verification, duplicate financial request, and authorized original-image retrieval. Use approved fixtures; no real-money test is implied.
- Co-developer changes should be merged after comparing RPC signatures, Auth assumptions, and the pending migration order. The Phase 3 branch must not be deployed by copying only Flutter files while the SQL/functions remain absent.

## Authorization and next work

Before live enablement, obtain an approved shared-project procedure for: (1) reviewing and applying only agreed migrations in order, (2) configuring Supabase phone/password and SMS provider, CAPTCHA/rate limits and OTP policies, (3) creating isolated synthetic owner/staff fixtures, and (4) running tenant, revocation, idempotency, renewal, and deletion tests. Define phone-change and lost-phone identity proof plus financial-record retention with the product/legal owner. Keep the feature flags off until these checks pass.

**Recommended next task:** review the two Phase 3 SQL migrations against a schema snapshot and agree on a synthetic acceptance procedure for the shared prelaunch project. Continue coordinating with the co-developer on the Phase 2 relay separately. There was no production deployment, live phone sign-up, remote migration, or financial operation in this phase.
