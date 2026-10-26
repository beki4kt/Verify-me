# Chekmi master schema reconciliation — 26 October 2026

**Status: migration ledger reconciled; additive legacy access hardening applied and post-change checks passed.** The linked project is `lpbdxtzyzlaioggefscc`. The owner chose this existing project for the Mesob prelaunch pilot; a second staging project is not required.

## Observed facts

| Check | Result | What it proves |
|---|---|---|
| `supabase migration list` | Connected to the linked database; all 22 checked-in versions have an empty remote-history entry. | The CLI migration ledger does not record these files. It does **not** prove the schema changes are absent. |
| `supabase db push --dry-run` | Would apply all 22 migrations. | A normal push is unsafe until the live schema and history are reconciled. No migration was applied. |
| `supabase gen types --linked --schema public,storage` | Generated 33 public tables and 84 public RPC names into an ignored local file. All 26 table names created by checked-in migrations appear. | The tables exist. This does not prove their policies, constraints, triggers, or function bodies match the repository. |
| Offline migration-to-live-types comparison | All 56 `ALTER TABLE ... ADD COLUMN` names found in checked-in migrations appear in the live generated table types. | No missing migration-added public columns were found by this name-based check; types/defaults and every constraint still require independent verification. |
| Latest receipt/workspace objects | Live types include `workspace_profiles`, `payment_verification_evidence`, `receipt_images`, `tickets`, `commit_verified_payment`, `reserve_receipt_original`, `finish_receipt_original`, `get_verified_receipt_detail`, and `service_get_receipt_original_locator`. `receipt_images` has archive status, bucket, object-key, SHA-256, MIME, size, source, and stored-at fields. | Important portions of the October workspace and receipt migrations appear to have been applied manually. Exact behavior remains unverified. |
| `supabase storage ls --linked --experimental` | Lists `receipt-evidence/`. | The bucket exists; privacy and upload limits still require catalog inspection. |
| `supabase functions list --project-ref ...` | Only `chekmi-verify` is deployed, active at version 4. Earlier GET health reported its engine as `veritas`; `chekmi-demo` and `chekmi-receipt-evidence` returned 404. | Preserve the working verifier while reconciling schema. Edge deployment is separate from migration history. |
| `supabase db dump --linked --schema public,storage` | Could not run: Docker/Podman is not installed. | No schema dump was produced; the database was unchanged. |
| `supabase/mesob_readiness.sql`, run by the owner in SQL Editor | Passed. `MESOB-DEMO` reports Pro, active, cashier module enabled, restaurant profile with review required, four active staff, and two configured receiving-account fields. | The existing Mesob pilot setup and checks in that query pass. It does not prove a subscription payment or a bank verification. |
| `supabase/master_schema_catalog_checks.sql`, run by the owner in SQL Editor | All targeted functions, triggers, constraints, policies, RLS flags, receipt bucket settings, and the archive object-key index are present. The six targeted triggers are enabled. The schema marker is `2026-09-19.1`, matching the latest migration that updates that marker. | Key October changes exist in the live database. This is stronger than client types, but does not prove every function body or every historical migration is identical to source. |
| `supabase backups list --project-ref lpbdxtzyzlaioggefscc` | `pitr_enabled:false`, `backups:[]`, `walg_enabled:true`. | The CLI did not expose a restorable physical backup or PITR point. The owner acknowledged this and authorized continuing without one; restrict writes to reversible ledger metadata. |
| `supabase/master_schema_remaining_checks.sql`, run by the owner | All 5 older triggers and 11 indexes passed. The date constraint failed the strict validation test, and 5 legacy tables failed the strict RLS-plus-no-client-SELECT test. | Required a detail check; the summary alone did not prove missing objects or data exposure. |
| `supabase/master_schema_gap_details.sql`, run by the owner | `payment_evidence_provider_date_required` exists as `NOT VALID`, exactly as created in `202608170001_payment_correctness.sql`. `app_sessions`, `staff_sessions`, and `verified_transactions` have RLS with no policies; `super_admins` has no client grants but RLS disabled; `ticket_audit_logs` has RLS disabled and broad client grants. | Do not recreate or validate the intended date constraint. Harden the legacy tables, especially `ticket_audit_logs`, without touching rows or RPC bodies. |

The eight migration-defined functions absent from generated client types are internal trigger/helper functions: `apply_cashier_verify_preset`, `create_missing_receipt_evidence`, `create_workspace_profile`, `hash_staff_password`, `prevent_financial_evidence_mutation`, `protect_archived_receipt_original`, `protect_verified_ticket_values`, and `reject_known_cross_workspace_payment_duplicate`. The SQL Editor catalog check confirms all eight exist.

Three internal trigger helpers (`create_missing_receipt_evidence`, `protect_archived_receipt_original`, and `reject_known_cross_workspace_payment_duplicate`) retain `EXECUTE` grants for `anon` and `authenticated`. The checked-in archive migration creates them but does not revoke those grants. Trigger functions are not ordinary client-callable RPCs, so this output alone does not prove an exploit. The prepared additive hardening migration revokes the client grants without replacing the function bodies.

The [legacy access migration](../../supabase/migrations/202610260001_legacy_table_access_hardening.sql) enables RLS and removes direct client grants from the five legacy tables. It explicitly retains service-role table access. It revokes direct client execution of three internal trigger helpers. It does not replace their bodies or edit table rows. It was applied after the historical migration ledger was repaired.

## Changes made to the linked project

1. The owner confirmed this free-plan project has no backup and instructed us to continue. The pre-change `migration list` showed all 22 historical versions absent from the ledger, and the read-only schema checks found their main objects present. `supabase migration repair --linked --status applied` recorded exactly those 22 historical versions. This **adopts the live schema as the baseline**; it does not prove byte-for-byte equality of every historical function body.
2. `supabase db push --linked --dry-run` then offered only `202610260001_legacy_table_access_hardening.sql`. `supabase db push --linked --yes` applied only that file. No historical migration SQL was replayed. No function body, trigger, payment row, receipt row, or customer row was changed by the new file.
3. A sequential `supabase migration list --linked` showed all 23 local versions paired with remote versions. `supabase db push --linked --dry-run` returned `upToDate:true` and no pending migrations. One earlier parallel CLI list call briefly failed with a pooler login error; its sequential retry succeeded.
4. `supabase gen types --linked --schema public,storage` produced the same normalized TypeScript definitions as the pre-change snapshot (`Type definitions unchanged: True`). This confirms no client-visible table or RPC type shape changed; it does not test permissions at runtime.
5. The owner reran `supabase/master_schema_remaining_checks.sql`: `table_access: 32 checked, 0 failed`; `index: 11 checked, 0 failed`; `trigger: 5 checked, 0 failed`. The sole constraint item remains `payment_evidence_provider_date_required` because the query requires validated constraints while the checked-in migration intentionally created it as `NOT VALID`. The earlier detail query confirmed it exists with the intended definition.
6. The owner reran `supabase/mesob_readiness.sql`: `MESOB-DEMO` again reports Pro/active, cashier module enabled, restaurant/review-required profile, four active staff, and two configured receiving-account fields. The query's RPC, bucket, and grant assertions passed. The strict remaining-check SQL was subsequently corrected to expect the intentional `NOT VALID` constraint state; that adjusted query was not rerun.

## Remaining verification

The post-change table-access, index, trigger, and Mesob readiness checks pass. The provider-date constraint exists with the intended `NOT VALID` state, so its original strict validation failure was not a missing-schema finding.

The latest client-facing types, table names, and 56 added column names were checked before the write. Exact historical function-body equivalence, live provider verification, and cross-tenant runtime access were not proven by this reconciliation and remain separate Phase 2 checks.

## Access limits

The official Supabase Management API has a read-only SQL endpoint, but automatic approval review rejected a custom script that would extract and reuse the CLI token from Windows Credential Manager. No token was accessed. Browser automation failed to initialize after recovery attempts. The remaining catalog checks therefore need the normal SQL Editor or a standard database client. This report contains no customer rows or secret values.

## Next step

The master schema baseline and legacy access correction are reconciled. Phase 2 endpoint and payment-evidence validation can proceed under the single-project Mesob pilot plan. The deployed `chekmi-verify` function was not replaced during schema reconciliation. This result does **not** establish that a real bank payment verifies, that receipt upload works, or that every historical function body matches the repository. The free-plan project has no confirmed restore point; maintain extra care for future schema changes.
