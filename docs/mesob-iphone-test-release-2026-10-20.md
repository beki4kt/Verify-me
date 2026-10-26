# Mesob iPhone test release — 2026-10-20

The AltStore IPA is an **unsigned native iPhone build**. The repository's
configured Supabase URL is the same project used by production. Do not treat
`CHEKMI_ENV=staging` or a local `config/staging.json` label as tenant isolation.
The existing-workspace catch-up query does not change Mesob members, passwords,
receiving accounts, subscription state, or historical payments.

## Database query

- Fresh isolated test project: run [`../supabase/CHEKMI_APP_TEST_SETUP.sql`](../supabase/CHEKMI_APP_TEST_SETUP.sql) once in the Supabase SQL Editor. It contains the base schema, all 22 dated migrations, Mesob seed, and readiness assertions.
- Existing Mesob project with `202610160001_inclusive_workspaces.sql` applied, but **neither** owner registration nor receipt archive applied: run [`../supabase/CHEKMI_MESOB_TEST_UPGRADE_20261020.sql`](../supabase/CHEKMI_MESOB_TEST_UPGRADE_20261020.sql) once. It applies both dated migrations and checks the existing Mesob workspace in one transaction. It does not seed accounts.
- Existing project with owner registration already applied: run only the pending [`../supabase/migrations/202610200001_receipt_evidence_archive.sql`](../supabase/migrations/202610200001_receipt_evidence_archive.sql), then the read-only [`../supabase/mesob_readiness.sql`](../supabase/mesob_readiness.sql). In an isolated test project only, run [`../supabase/seed.sql`](../supabase/seed.sql) if Mesob is absent.

Never paste the fresh-project bundle into a database that already has those
migrations. For a managed project, prefer `supabase db push` so migration history
is tracked. Running SQL manually in the SQL Editor does not mark the migration
as applied in Supabase CLI history; reconcile that history before a later push.
The fresh-project test bundle **does** contain known demo credentials. Do not
run it on the configured production-backed project.

SQL provisions the private `receipt-evidence` Storage bucket and RPCs. To make
the app functional, also deploy both bundled Edge functions from this commit:
`chekmi-verify` and `chekmi-receipt-evidence`. The verification function needs
the existing self-hosted relay secrets; the evidence function needs the
Supabase service role key in its server environment. Do not put either secret
in the iPhone build. Check each function's GET readiness endpoint before
testing, and do not switch a live verifier until its database migration passes.

## Mesob test journey

1. Install the IPA through AltStore and connect the `MESOB-DEMO` workspace with
   an existing test member. The test seed creates admin, cashier, and waiter
   members with workspace-scoped phone/password credentials.
2. Open the payment flow. Capture a genuine JPEG/PNG receipt or import one from
   Photos. Verify a transaction that really belongs to the configured Mesob
   receiving account. OCR is a reference aid; it is not bank verification.
3. Open Activity and the verified receipt detail. Confirm amount, provider,
   provider reference, transaction time (if supplied), masked receiving
   account, and the original image. Zoom the image and verify that business
   completion is displayed separately from provider verification.
4. Try a reference-only payment. It should appear as verified with
   `missing_original`; attach a genuine image later. Temporarily interrupt an
   upload and retry it. The verified payment must remain, while the evidence
   state changes from incomplete to stored.
5. Repeat the same provider transaction. It must not increase the ledger a
   second time. Check another workspace cannot open Mesob's receipt detail.

The latest subtype-driven onboarding, Events workspace, and phone-first owner
login are still **browser preview designs**. They are not implemented in the
native app or database and cannot be made functional by this SQL. The current
native owner registration still uses the existing Supabase email verification
and pending-activation process. Mesob remains a restaurant workspace; the
illustrative Events flow does not change its data or permissions.

No production database migration, Edge deployment, Apple signing, or real bank
verification is performed by building the IPA. A successful CI build proves
the native artifact compiles; the end-to-end receipt journey still needs a
configured test backend and an actual iPhone run.
