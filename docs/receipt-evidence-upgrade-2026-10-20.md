# Receipt evidence upgrade — implementation and deployment review

This change is prepared in source only. No production database migration, Edge deployment, or real-bank receipt upload was performed.

## Initial architecture audit

| Component | Existing state | Action |
| --- | --- | --- |
| Capture | Camera/OCR and manual reference in `lib/waiter_dashboard.dart`; no gallery import | Preserve camera/OCR; add photo import, preview, replace, and true original-byte upload |
| Original image persistence | `public.receipt_images.image_data` held a compressed JPEG/PNG (maximum 1.5 MB) | Keep historical rows; archive new originals in private Supabase Storage |
| Verification metadata | `public.payment_verification_evidence` and `tickets.verification_evidence_id` held provider results and context | Reuse them; add scoped detail projection, never trust OCR for bank status |
| Secure file access | Custom staff-token `get_receipt_image` RPC; no private object bucket | Add private `receipt-evidence` bucket and server-authorized Edge transport |
| History linking | Tickets and admin image dialog; staff history lacked full details | Link shared detail screen from staff and admin history; add receipt search |
| Duplicate protection | Existing `(business_id,provider,transaction_ref)` uniqueness and status recovery | Keep; add a cross-workspace guard when provider reference and full destination match |
| Recovery/retry | Image was part of atomic payment commit; storage errors could undo a valid result | Commit payment first, then reserve/upload/finalize original with same-image retry |
| Detail UI | Admin image-only dialog | Add amount, bank, timestamps, context, masked destination, evidence state and zoom |

The audit also found `business_data_retention.receipt_retention_days` and historical restaurant `ticket_id`, `waiter_id`, and `table_number` fields. They remain intact.

## Flow and integrity

1. The existing trusted provider verifier commits immutable `payment_verification_evidence` and its ticket. The Edge verifier now passes `p_receipt_image_base64=null`, so receipt upload cannot roll this back.
2. A ticket trigger creates a `missing_original` receipt row when no image was supplied. Existing compressed historical images remain in `image_data` and are marked `stored` / `legacy`.
3. The app sends selected camera/gallery **bytes**, unchanged, to `chekmi-receipt-evidence` after verification. Manual-reference payments stay verified with `missing_original` until an authentic image is attached.
4. The new Edge function validates actual JPEG/PNG structure, dimensions, 6 MB limit and SHA-256, then reserves a tenant-scoped object key through a staff-authorized RPC. It uploads without upsert to a private bucket and finalizes only after a matching Storage object exists. A second call with the same bytes recovers a timed-out finalization; a different archived original is rejected and logged.
5. Staff and owners see only receipts allowed by their custom-session membership. The mobile app never receives a service-role key or a permanent public object URL. Downloads pass through an authorized Edge function; access is audited. Date/provider/staff filtering is preserved; history now also searches amount, reference and context. Verification status and business completion status remain distinct.

The database stores exact existing `numeric` monetary values; no floating-point revenue calculation was added. Historical compressed images cannot be reconstructed into the pre-compression camera original and are labeled as legacy in the detail screen.

## Files and configuration

- Additive schema/bucket migration: `supabase/migrations/202610200001_receipt_evidence_archive.sql`
- Edge source/tests: `backend-server/src/edgeReceiptEvidence.ts` and `.test.ts`
- Bundled deployment entry: `supabase/functions/chekmi-receipt-evidence/index.js` (set `verify_jwt=false`; the function checks Chekmi staff sessions through tenant-scoped RPCs)
- Payment Edge adjustment: `backend-server/src/edgeVerification.ts` and rebuilt `supabase/functions/chekmi-verify/index.js`
- Flutter: `lib/api_service.dart`, `lib/waiter_dashboard.dart`, `lib/admin_dashboard.dart`, `lib/receipt_details_screen.dart`; `image_picker` dependency and iOS photo-library usage text
- Isolated browser demo: `preview/receipt-evidence/`

Apply the migration on a staging Supabase project, deploy the receipt function, deploy the updated verification function, and only then test an updated app build. The new app requires both functions and the migration. A production rollout should keep old clients compatible until upgraded; older clients that still send a photo to the new verification function will receive a verified payment with `missing_original` and must attach the original afterward.

## Validation and known limits

`npm test`: 59 passing backend tests including genuine-byte storage, failed upload, same-image retry after finalization interruption, corrupt file rejection and tenant isolation using test doubles. `npm run build`: passed. `flutter analyze --no-pub`: passed. `flutter test --no-pub`: 85 passed, two skipped by their existing conditions. Browser automation exercised 320/375/390/430 px, failure/retry, zoom and reload; screenshots are under `preview/receipt-evidence/screenshots/`. The browser fixture is illustrative and stores chosen bytes only in local IndexedDB; it performs no provider verification.

The migration has **not** been executed against PostgreSQL because local `psql`, Supabase CLI and Docker are unavailable. No iOS/Android device camera or gallery run has occurred in this Windows environment. A staging run must verify Storage object metadata, RPC grants, legacy image reads, two-workspace isolation, expired tokens, real JPEG/PNG/HEIC handling, mobile interruption, and retention behavior. HEIC originals are currently rejected with a clear JPEG/PNG requirement; they are never silently converted while claiming to be original.

The current retention setting records a period but there is no legally reviewed object-purge job. Archived originals are immutable and cannot be silently deleted; secure deletion needs a separate reviewed procedure that removes the object through the Storage API and records the retention action. The optional Chekmi-branded summary image and private export flow were deferred until staging proves original preservation. No financial records or subscription states were changed in production.

Event/category/station filtering is not yet backed by production event models, so the common receipt history uses the existing typed reference and ticket context. Adding those filters requires the separate event-context migration, not a parallel receipt archive.
