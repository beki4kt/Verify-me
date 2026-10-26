# Chekmi Phase 2 — payment integrity and receipt evidence

**26 October 2026 — implementation in progress; live financial acceptance is not yet proven.** The owner chose the existing prelaunch Supabase project and MESOB-DEMO for the controlled pilot. It is one shared environment. No real provider transaction, production SMS, or synthetic bank-confirmed payment was created for this report.

## Deployment facts

| Component | Observed result | Limit |
|---|---|---|
| chekmi-verify | GET 200, ready, engine veritas | The deployed verifier is still the older Veritas implementation. Health is not proof of a successful payment. The new bundle is not deployed. |
| chekmi-receipt-evidence | Deployed version 1; unsigned GET 401; fake-session GET 403 | Reachable and rejects those unauthorized requests. Successful upload/retrieval and two real tenant sessions remain untested. |
| chekmi-demo | GET 404 | Demo remains unavailable; it needs authorized backend lookup configuration. |
| Owned backend API | Edge secret-name listing did not contain CHEKMI_BACKEND_URL or CHEKMI_INTERNAL_LOOKUP_KEY | The Edge-to-Node private lookup is not configured on this project. No key value was printed or saved. |
| Prior Alet Node URL | The older deployment guide's chekmi.app.aletcloud.com returned HTTP 404 for /health, /ready and /api/internal/provider-lookup on 26 October | No current Node deployment is established by that historical guide. |
| Second recorded Alet URL | chekmi-backend-1.app.aletcloud.com returned HTTP 404 for /health, /ready and /connectivity on 26 October | This address also does not establish a running Node deployment. |
| Ethio Telecom Plesk | Owner screenshot on 26 October shows Node.js Toolkit available with Node 22.23.4, but disabled on the PHP relay domain; application and document roots both point to its `/httpdocs` | A separate subdomain/root is required before enabling Node. The screenshot does not prove that a Node app has started. |
| Database | Prior catalog checks and Mesob readiness passed except the intentionally unvalidated historic provider-date constraint | Private JPEG/PNG bucket capped at 6 MiB exists. Mesob is active Pro with four active staff and two configured receiving-account fields. These observations do not prove a payment journey. |

## Implemented in this checkout

1. [Edge verifier](../../backend-server/src/edgeVerification.ts) now supports an explicit Veritas or owned engine. If unset, the existing Veritas key retains that path; switching to the owned relay requires explicit configuration. Both paths use the same trusted session, destination, freshness, duplicate lookup, and database commit. Provider requests exclude the original image and staff token.
2. Capability-authorized cashiers can verify without a restaurant table. Bank verification and business completion remain distinct. The Edge response uses the database tip and unresolved-excess values; it never calculates a tip from the payment difference.
3. Expected and provider amounts must be positive ETB values with whole cents and safe minor-unit range. The comparison uses minor units. Invalid money and other currencies cannot reach the financial commit.
4. The parsed Veritas provider envelope is saved with normalized evidence in the private database row. Nested PDF/image base64 fields are omitted. Authentic receipt photos use the separate private archive.
5. [Future-tip migration](../../supabase/migrations/202610260002_explicit_future_tips.sql) converts existing legacy-tip workspace profiles to unresolved and prevents the legacy mode from being re-enabled. Historical ticket tips, allocations, payouts, payments, images, and audit records are untouched. **Prepared, not applied.**
6. Rebuilt the [standalone verification bundle](../../supabase/functions/chekmi-verify/index.js) from tested source. **Not deployed.**
7. Compared both supplied PHP-relay documents with the Node adapters. [M-Pesa](../../backend-server/src/ownedVerifier/otherProviders.ts) now accepts a strictly checked JSON receipt in base64Data as documented, while retaining the older PDF path. Relay-side authentication failures, missing references, uncertain replies and malformed receipts fail closed. [Telebirr](../../backend-server/src/ownedVerifier/telebirr.ts) recognizes the documented Amharic completion status and distinguishes key failure, not-found and upstream failure. [CBE](../../backend-server/src/ownedVerifier/cbe.ts) treats a documented invalid-token bank response as a nonretryable rejection rather than a generic outage. A relay-key failure is now returned by the Edge verifier as a nonretryable configuration error without exposing the backend's message. These are local contract tests, not proof of current live provider payloads.
8. The [host preflight](../../backend-server/scripts/host-preflight.mjs) now handles proxy egress: it checks relay-host TLS plus the three directly contacted banks and Supabase without requiring the Node host itself to have an Ethiopian IP. It rejects missing or placeholder keys without printing them, and checks a configured HTTPS port. Readiness also rejects example relay keys. A TLS pass still does not prove key validity, receipt correctness or bank availability.

## Reused architecture

The supplied CONNECT-VERIFY-ME.md, last dated 15 October, describes chekmiverifier.com.et as an Ethiopian PHP **bank egress relay**. It is not the Node backend API expected by CHEKMI_BACKEND_URL. The repository's backend .env.example already lists its Telebirr, CBE and M-Pesa relay URLs; their private keys belong only in the Node host's secret environment. The document's 7/7 reachability result is historical and was not reverified for this report. A read-only 26 October probe of the supplied host returned HTTP 200 for / and /status.php, but HTTP 404 for the Node application's /health, /connectivity and /api/internal/provider-lookup routes. No request contained a relay key, transaction reference, or staff session.

The subsequently supplied VERIFY-API.md confirms that the same PHP service is stateless and exposes only the bank-relay GET endpoints. It documents M-Pesa base64Data as JSON, whereas the earlier Chekmi source and documentation assumed a PDF. Both formats now have a fail-closed decoder, but the actual live format and field names require an authorized redacted or genuine test receipt. An unauthenticated read-only probe of the old Alet URL also returned 404 for the Node health and API routes. The current [Node deployment runbook](../../backend-server/README.relay.md) replaces the stale host assumption.

The existing `chekmi-vps` SSH alias is not a fallback deployment target: the older [deployment record](../owned-verifier-deployment.md) says its setup failed and Alet App Hosting replaced it. The first read-only SSH attempt stopped at a changed host-key warning; the warning was not bypassed. The Windows hosting-console automation helper was unavailable. No authenticated Alet deployment path is established in this environment, so the prepared ZIP has not been uploaded.

After the owner confirmed the changed SSH fingerprint through the provider console, the saved host entry was updated and a read-only hostname attempt reached the server but failed public-key authentication. The owner later clarified the Alet VPS had expired; this old alias is not the deployment path. A subsequent Plesk screenshot established that Ethio Telecom's existing PHP subscription exposes Node.js Toolkit. A separate [Plesk deployment runbook](../../backend-server/README.plesk.md) and [local package](../../build/Chekmi-Backend-Plesk-20261026.zip) were prepared without modifying the relay's `/httpdocs`. The package is not uploaded or running.

- The verifier checks a trusted provider result and configured receiving account, looks for an existing commit, then calls the atomic commit_verified_payment RPC. Same-worker in-flight protection, bounded lookup retry, database uniqueness, and a known cross-workspace duplicate trigger exist. Database concurrency has not been exercised with live sessions.
- The [inclusive workspace schema](../../supabase/migrations/202610160001_inclusive_workspaces.sql) separates automatic completion, review, evidence, unresolved excess, and explicit authorized tip allocation. Existing restaurant tips remain readable. The financial action RPC records void/refund/dispute events; Chekmi does not initiate bank refunds.
- The [receipt archive schema](../../supabase/migrations/202610200001_receipt_evidence_archive.sql) keeps legacy images and adds private Storage, SHA-256, source, upload state, reservation/finalization, quota, and tenant-scoped retrieval. Manual verification truthfully records a missing original.
- The [evidence handler](../../backend-server/src/edgeReceiptEvidence.ts) validates JPEG/PNG bytes, size and dimensions, uploads without overwrite, and recovers a partial upload. Image failure cannot reverse a genuine bank verification.
- The [mobile receipt flow](../../lib/waiter_dashboard.dart) supports camera/gallery, manual reference, preview, upload retry, searchable history and date/provider filters. [Receipt details](../../lib/receipt_details_screen.dart) show actual metadata, the original when available, and missing/failed states.

## Actual tests

| Command or check | Result | Limit |
|---|---|---|
| Backend npm test | **72 passed, 0 failed** after relay and Plesk package changes | Local provider, DB and Storage doubles. Covers both engines, relay JSON/PDF selection, deterministic relay errors, placeholder key rejection, destination, date, money, duplicate recovery, upload/retry/checksum and two synthetic tenants. |
| node --test backend-server/scripts/preflight-targets.test.mjs | **3 passed, 0 failed** | Validates proxy target selection, placeholder rejection and HTTPS port handling locally, without bank requests. |
| Backend npm run build | **Exit 0** | TypeScript compilation only. |
| node backend-server/scripts/build-edge.cjs | **Exit 0** | Bundle generation, not deployment. |
| Five relevant Flutter test files | **22 passed** earlier on 26 October | Client/unit tests, not device or live provider proof. No Dart source changed in this work. |
| flutter analyze --no-pub | **No issues found** earlier on 26 October | Static analysis only. |
| Supabase db push --dry-run --linked | **Exit 0; only 202610260002_explicit_future_tips.sql pending** | No database changes. |
| Current-project GET probes | Verify 200/Veritas; demo 404; evidence 401 unsigned | Endpoint observations only. |
| Local deployment ZIP | [Chekmi-Backend-Relay-Phase2-20261026.zip](../../build/Chekmi-Backend-Relay-Phase2-20261026.zip), SHA-256 2B6F1C2E950C9FDE01247BC247F05080A1CDC2E8FF386ABB0857B53EE2967249 | 137 entries, current runtime and runbook present, zero private-file names. Local ignored artifact; not deployed. |
| Plesk deployment ZIP | [Chekmi-Backend-Plesk-20261026.zip](../../build/Chekmi-Backend-Plesk-20261026.zip), SHA-256 5956E2575D55751E9CE10243212A37BF4A59C189E6CCF36885C5D802F8E67631 | 138 entries, includes root `app.js`, compiled runtime, private-outside-public layout and Plesk runbook; zero private-file names. Local ignored artifact; not deployed. |

The free-plan project has no confirmed restorable backup. The historic provider-date constraint remains NOT VALID for old rows but enforces new inserts.

## D/E audit status update

The baseline is [CHEKMI_PRODUCTION_READINESS_AUDIT.md](../audits/CHEKMI_PRODUCTION_READINESS_AUDIT.md); the requested numbered audit file was unavailable. No live financial workflow is promoted to **IMPLEMENTED & TESTED** based on local doubles.

| IDs | Status | Evidence still needed |
|---|---|---|
| D01 | NOT VERIFIED | Authorized genuine result for every claimed provider. |
| D02–D04 | PARTIAL | Mobile/manual paths exist; physical camera/gallery and provider journeys pending. |
| D05–D13 | PARTIAL | Server validation and immutable commit exist; controlled deployed transaction pending. |
| D14–D17, D26–D29 | PARTIAL | Local duplicate, retry, outage and concurrency tests pass; live cross-worker/database behavior pending. |
| D18–D25 | PARTIAL | Separate completion/evidence models exist; live bundle and future-tip migration pending. |
| D30 | PARTIAL | Financial action/event schema exists; no external bank refund or real action test. |
| E01–E03 | PARTIAL | Native capture/import and truthful manual state exist; device checks pending. |
| E04–E19 | PARTIAL | Private archive, checksum, retry and local tenant tests exist; real authorized image/tenant test pending. |
| E20–E25 | PARTIAL | Shared history/detail/search exists; real Mesob record and export checks pending. |
| E26 | MISSING | Reviewed retention and deletion policy/procedure. |
| E27–E29 | PARTIAL | Original and summary data are separate; size and duplicate controls exist; summary/device performance incomplete. |
| E30 | NOT VERIFIED | Historical restaurant image must be opened from a real legacy row. |

## Remaining acceptance work

1. **Live no-silent-tip rule is not yet true.** The deployed verifier and Mesob legacy-tip policy can still label future excess as tips. Apply the prepared migration and deploy the tested bundle only with explicit rollout authorization. Confirm Mesob then reports unresolved policy.
2. Configure the chosen provider engine securely. Veritas requires its existing key and explicit engine selection during rollout. Owned requires a separately deployed HTTPS Node backend /api URL plus matching private lookup key on the Node host and Supabase Edge. The Node host then needs the three PHP bank-relay URL/key pairs from its secure environment. Never send keys in chat or embed them in the app.
3. Use only an explicitly authorized genuine Mesob test reference. Verify once, check immutable evidence/ticket/event counts, attach the original photo, retrieve it as Mesob, deny Workspace B, then repeat the reference and prove no second credit. Test the supported providers and uncertain responses with authorized fixtures/sandboxes where available.
   In particular, inspect an actual M-Pesa decoded receipt or a redacted provider fixture before claiming the new JSON field mapping works live.
4. Check the physical iPhone camera/gallery, interrupted upload, historical image access, adjustment reporting, and retention/recovery procedure. The demo 404 is separate from the bank-payment acceptance path.

If rollout fails, stop new verification attempts and restore the prior function bundle only if its database contract remains compatible. Preserve every confirmed payment and original; use an additive correction rather than deleting history.

**Phase 2 is not complete.** The local integrity and archive implementation is materially stronger, but live provider, tenant, image, migration and device acceptance remain. No Phase 3 work or production app release began here.
