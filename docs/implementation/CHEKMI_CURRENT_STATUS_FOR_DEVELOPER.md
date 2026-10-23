# Chekmi status for a co-developer — 23 October 2026

Chekmi is a Flutter payment-receipt verification app backed by a Node/TypeScript relay and Supabase Auth, PostgreSQL/RLS, Storage, and Edge functions. The same payment engine serves restaurant and generic workspace flows. The app is suitable for **controlled internal testing**, not a public App Store or Play Store release yet.

## What is in the app

- Native iPhone/Android Flutter client: workspace connection and staff sign-in, owner email/password registration with pending activation, receipt camera/photo capture, manual reference entry, provider verification flow, transaction history and receipt detail, and Mesob's restaurant workflow.
- Receipt-evidence code separates bank verification from image-upload status. An upload failure should not reverse a genuine bank result; the private Storage bucket and service-only access rules are defined in migration `202610200001_receipt_evidence_archive.sql`.
- Five-category/subtype onboarding, phone-first owner login, and Events screens are **interactive browser-preview concepts**. They are not complete native, deployed business workflows. An onboarding card or preview transaction is not proof of bank verification.
- The actual owner sign-in remains email-based. Subscription activation is pending real approval/payment rules; a selected plan is not automatically active.

## Phase 1 changes now in source

- Client and backend configuration reject known production coordinates in nonproduction mode. Local development, offline preview, staging, and production have explicit build settings.
- A staging-only Supabase deployment workflow, schema assertions, synthetic Mesob/isolation fixtures, and a staging-target guard are prepared.
- Health monitoring recognizes the observed `veritas` verifier engine and distinguishes missing endpoints from unauthorized and healthy responses.
- Backend production dependencies were patched; the local production-package audit found zero advisories. Local Flutter and backend suites passed during Phase 1.

**Deployment status:** Phase 1 is **not fully live**. As of this handoff, no separate staging Supabase project or GitHub `staging` environment was available. The current local `config/staging.json` still points to production and is intentionally rejected. No Phase 1 migration or Edge function was deployed to production. The last read-only production probe found `chekmi-verify` ready, while `chekmi-demo` and `chekmi-receipt-evidence` returned HTTP 404. The private evidence archive and cross-workspace isolation are therefore not yet proven end to end.

## iPhone builds and testing

- **Offline preview IPA:** `.github/workflows/ios-offline-preview.yml` builds the latest Flutter source on a GitHub macOS runner with `CHEKMI_ENV=preview`. It is unsigned for AltStore. It can show the iPhone UI and guided illustrative preview; it cannot sign in to Mesob or perform live bank/evidence operations.
- **Functional staging IPA:** `.github/workflows/ios-altstore.yml` requires a separately provisioned staging Supabase project, backend, GitHub `staging` variables/secrets, applied migrations, and deployed Edge functions. Its preflight rejects the known production project/hosts. Do not relabel production credentials as staging.
- A Windows computer cannot compile a native iOS binary locally; GitHub Actions supplies macOS/Xcode. An IPA build proves compilation, not physical-device or backend behavior.

## Next work in order

1. Provision isolated staging Supabase/Auth/Storage and backend with synthetic Mesob data. Configure the protected GitHub `staging` environment. Follow [Phase 1 runbook](PHASE_1_FOUNDATION_REPORT.md).
2. Run staging migration dry-run, apply the required migrations/functions, and verify `chekmi-demo` and `chekmi-receipt-evidence` plus two-workspace Storage/RLS isolation.
3. Build the functional staging IPA and test real iPhone capture, reference verification, duplicate handling, upload/retry, history, and permission revocation with authorized **test** provider data.
4. Finish the native phone-first/industry onboarding only after its Auth and billing contracts are designed and tested. Complete signed-device QA, store compliance, backup restore, and operational monitoring before public release.

For detailed evidence and unresolved risks, see the [concise production audit](../audits/CHEKMI_PRODUCTION_READINESS_AUDIT.md) and [Phase 1 implementation report](PHASE_1_FOUNDATION_REPORT.md).
