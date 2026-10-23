# Chekmi product status for a co-developer — 23 October 2026

Chekmi is one payment-receipt verifier for businesses and individuals, built with Flutter, a Node/TypeScript verification relay, and Supabase Auth/PostgreSQL/RLS/Storage/Edge functions. **Current recommendation: controlled internal testing only.** The native app has a real payment workflow, but several backend services and customer journeys are not yet proven or complete enough for public release. This document separates native code, illustrative previews, and deployed behavior.

## Current UI and user journey

- **Native iPhone app:** A logo splash leads signed-out users to a welcome screen with Get Started, Connect to Existing Workspace, and Explore Preview. Workspace code entry precedes staff sign-in. Activated owners and staff are routed to a workspace home or the preserved restaurant dashboards. The generic home shows Verify Payment, Review Payments, Activity/Ledger, Settings, and Members according to server-provided capabilities ([entry and routing](../../lib/main.dart), [welcome](../../lib/launch_experience.dart), [workspace home](../../lib/workspace_home_screen.dart)).
- **Visual state:** Native screens reuse the real Chekmi mark, iOS-style navigation, cards, status states, and light/dark themes. They are **not yet visually unified** with the approved premium browser concept: native theme tokens currently use graphite/violet/cyan, while the browser onboarding preview uses midnight navy/electric blue/orange. Some legacy restaurant dashboards also retain older patterns ([native tokens](../../lib/core/theme/app_colors.dart), [browser tokens](../../preview/premium-onboarding/styles.css)). This is a design-integration task, not a backend capability.
- **Preview distinction:** The native Explore Preview is a labeled sample walkthrough; its live-demo link depends on a separate service. The richer browser prototype includes animated splash, five business categories, subtype-specific questions, workflow adjustment, phone-first forms, and an Events example. It makes no production authentication or payment calls and is **not loaded by the Flutter app** ([native preview](../../lib/guided_preview_screen.dart), [browser preview README](../../preview/premium-onboarding/README.md)).

## What the native app can do today

| Area | Current implementation | Practical limit |
| --- | --- | --- |
| Access and onboarding | Connect an existing workspace with a code; staff sign in with assigned credentials. A business owner can choose one of four broad presets, Just Me/My Team, automatic/review completion, a Basic/Pro plan, and a receiving account, then request activation. | Owner identity is still **email/password with email confirmation**, with phone collected as contact data. Registration does not grant an active subscription automatically. Personal self-service remains gated. |
| Verify a receipt | Select a provider, scan with the camera or import a photo, use OCR as a reference aid, or enter the transaction reference manually. Submit expected amount and optional business context to the trusted verifier. | OCR is not bank proof. Provider, destination, duplicate, retry, and timeout logic has local tests; complete live provider/device coverage is not yet proven. |
| Payment outcome | Code records verified amount, provider reference, expected-versus-actual amount, verification evidence, and separate business completion. Automatic completion or authorized review depends on workspace policy. | Live financial integrity, concurrency, and receiving-account checks still require isolated staging tests. |
| Receipt archive | Code provides history/search, receipt details, original-image states, upload retry, and a private evidence-storage design. Reference-only payments can truthfully lack an original image. | The deployed receipt-evidence endpoint last returned 404, so live original-image archival/retrieval is not established. |
| Workspace operations | Generic workspace actions, editable payment settings, receiving accounts, member capabilities, ledger/report filters, and the existing Mesob restaurant cashier/table/tip workflow are present in source. | Availability varies by role and plan; cross-workspace security and all business journeys are not yet proven against a live staging system. |
| Business tools | Admin screens include staff/account management, audit CSV export, support/privacy screens, and English/Amharic switching. | These paths need device and backend acceptance; some product copy still lacks complete translation. |
| Plans and demo | Basic/Pro catalog and pending activation screens exist. Guided sample preview works without a bank call. | Pro pricing is not defined in the catalog; the live demo endpoint last returned 404. A plan choice is not a paid, active subscription. |

The implementation above is a code/UI inventory, **not** a claim that every operation works end to end in the current deployed environment.

## How inclusive Chekmi is now

The shared workspace profile already stores a broad use case, default reference kind, automatic or review-required completion, tips setting, and overpayment policy. Payment context can be none, invoice, order, booking, customer, table, or note. The generic home uses capabilities rather than an industry name to decide which actions appear ([profile](../../lib/core/models/workspace_profile.dart), [contexts](../../lib/core/config/payment_context.dart), [settings](../../lib/workspace_settings_screen.dart)).

| User type | Current level |
| --- | --- |
| Restaurant | Most mature native path: existing Mesob-style waiter/cashier/table workflow, optional tips and ledger. Historical records are preserved in the migration design. |
| Shop or single cashier | Generic order/reference and one-person or team setup exist. A fully demonstrated single-cashier sale and multiple-counter workflow still need staging/device acceptance. |
| Services | Invoice/booking/customer context and generic verification UI exist. Job-specific operations and complete service-provider onboarding are not finished. |
| General or personal | Generic verification can avoid table/tip terminology; one-member policy is modeled. Open personal registration, recovery, deletion, and phone-first identity are not finished. |
| Events & Venues | Category, subtype, and sample event/category/station journey exist **only in the browser preview**. Native data model, event ledger, and reporting are not implemented. Ticketing is intentionally outside scope. |

The present native registration has **four** broad presets. The approved **five-category, subtype-driven** experience is a browser design target, so do not advertise it as a shipped mobile feature.

## Planned structure

The product direction is **one app, one trusted verification engine, one ledger and audit trail, configurable workspaces**. Shop, restaurant, service, personal, and Events are presets for wording, default references, and optional modules—not separate apps or permission roles. The owner should be able to change a preset without losing receipt history ([inclusive workspace plan](../inclusive-workspaces-plan-2026-10-16.md)).

The shared payment path is: capture or enter a genuine receipt reference → verify against the provider and configured receiving account → record immutable bank evidence once → optionally store the original image → automatically complete or send for authorized business review → display it in the same workspace ledger. Duplicate and uncertain responses must never create another confirmed payment. Tips and excess amounts remain separate; extra money is not automatically a tip. Server-side membership and capabilities govern access, independent of what the UI hides.

The intended customer journey is short personalization (category → subtype → tailored workflow), real plan selection, secure owner registration, receiving-account setup, activation, then a dashboard composed from capabilities. A solo user gets Verify/Activity/Settings; a team can add reviewers and members; a restaurant keeps its table/cashier tools; Events would add payment context and summaries, not ticketing. The browser prototype demonstrates the interaction model, but subtype IDs, Events data, and phone-first Auth still require native/backend implementation.

## Phase 1 and build status

Phase 1 added fail-fast development/preview/staging/production settings, a staging-target guard for the client and backend, a prepared staging deployment workflow, schema and two-workspace checks, corrected verifier health checks, and compatible backend dependency patches. These changes are **in source**, not a completed staging deployment ([Phase 1 report](PHASE_1_FOUNDATION_REPORT.md)).

As of 23 October, no separate staging Supabase project or GitHub staging environment was configured. The local staging file still points to production and is rejected. The last read-only production probe reported the verifier ready, but the demo and receipt-evidence endpoints returned **HTTP 404**. No production migration or deployment was performed. Live receipt access, tenant isolation, and full Mesob verification are therefore unproven.

The latest [iPhone build run](https://github.com/beki4kt/Verify-me/actions/runs/39949604255) succeeded. It produced an unsigned **offline preview IPA** from commit `d36d040`, with Phase 1 source included. Its ZIP/IPA hashes and ARM64 contents were checked. It has no live authentication, bank verification, or evidence upload. A functional Mesob staging IPA depends on an isolated staging project and deployed services; the prepared [staging IPA workflow](../../.github/workflows/ios-altstore.yml) rejects production coordinates. A successful build is not a real-device or provider test.

Local evidence at this point: **88 Flutter tests passed, 2 skipped; Flutter analysis clean; 61 backend tests passed; backend TypeScript build passed; seven environment/health tests passed.** These are local code tests, not end-to-end financial acceptance.

## What prevents publication

1. **Backend and data isolation:** Provision separate staging Auth/database/Storage/backend, reconcile migrations, deploy the missing demo and receipt-evidence functions there, then prove two-workspace RLS and private-image isolation. Do not test against production-labelled staging.
2. **Payment and evidence acceptance:** On staging and physical devices, verify real authorized test receipts across claimed providers, wrong destinations, failed/uncertain results, duplicates, simultaneous submissions, amount differences, original-image upload/retry, and unchanged historical restaurant data. Until that passes, payment and archive reliability cannot be claimed.
3. **Identity, onboarding, and billing:** Safely implement or explicitly defer phone-first owner login, verified phone ownership, recovery, account deletion, anti-abuse controls, and existing-email-owner compatibility. Move the approved five-category/subtype journey into native only with matching data model and editable settings. Prove plan limits, approval/activation, expiry, and historical-data access; do not market preview-only Events or undefined Pro pricing as live.
4. **Product UI consistency:** Align native splash/welcome/login/onboarding and operational screens with the approved navy/blue/orange design without breaking the restaurant flow. Remove remaining restaurant terms from generic paths; test solo, single-cashier, team, service, and restaurant journeys on small iPhones and Android devices, including accessibility and language behavior.
5. **Release operations and store requirements:** Produce signed iOS and Android release builds, run physical-device QA, prepare reviewer access and live backend availability, verify backup restore and monitoring, finalize privacy/deletion disclosures, billing classification, provider authorization, store metadata, and support procedures. The [production-readiness audit](../audits/CHEKMI_PRODUCTION_READINESS_AUDIT.md) records the detailed evidence and open risks.

**Recommended next task:** finish isolated staging and restore the two missing services, then test Mesob's receipt-verification-to-evidence path there. That creates a safe foundation for the native redesign and broader business onboarding.
