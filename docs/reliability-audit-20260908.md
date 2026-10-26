# Verification and app audit — 8 September 2026

## Result and deployment

Telebirr was confirmed working on the user's iPhone after function version 2026-09-08.1. Intermittent failures were reported afterward. Historical server logs were not available in this session, so the exact mix of Veritas errors versus timeouts is not yet measured. Local recovery tests do not establish a live uptime percentage.

Deploy the accompanying Supabase function version 2026-09-08.2 for lookup recovery. Install the accompanying IPA for dashboard and scanner fixes. An IPA reinstall alone does not update the verification function. No database migration is needed for these changes.

## Fixed in this audit

| Finding | Change | Evidence |
|---|---|---|
| One short provider/network outage immediately ended verification | At most two standard ID lookup attempts within the existing 45-second request deadline, reserving time for saving | Simulated 502 followed by success produces exactly one commit; repeated outages stop after two calls |
| HTML error bodies hid the real access/credit/rate-limit failure | Inspect HTTP status before attempting JSON parsing | HTML 401/402/429 retain their correct error categories and are not retried |
| No useful provider-latency diagnostics | JSON logs include request ID, provider, attempt, HTTP status, elapsed time and transport outcome | No API key, staff token, account, receipt reference, receipt body or raw exception is logged |
| A transient RPC exception permanently ended dashboard streams | Shared recoverable polling for business, ticket, report, attempts, withdrawals and staff data | Tests cover failed poll recovery, late-subscriber replay and cancellation |
| Old polling work could observe a new login's global token | Capture the session token for each stream and discard results after it changes | In-flight old-session response is not emitted |
| Tabs could subscribe after the latest value and wait indefinitely | Replay cached data to each listener; stop work when all listeners leave | Late subscriber and leave/rejoin tests pass |
| Numeric Dashen references were rejected by OCR parsing | Accept its provider-specific 16-character form with three leading digits | Numeric/alphanumeric references accepted; phone number rejected |
| New CBE URL/token case was lost by OCR normalization | Preserve original case before generic text normalization | Mixed-case URL and token tests |
| Scanner could update a disposed widget; OCR resource leaked on failure | Check mounted before state update and close recognizer in finally | Static analysis; physical-device navigation test still required |
| Payment provider could change during submission | Disable provider selector while submitting | Code inspection and iPhone layout regression suite |
| An HTML response could hide a payment already saved | Client performs one read-only saved-status recovery | Same status-only recovery path as timeouts; never repeats the paid lookup from the phone |
| Underpayment instructions suggested an unsupported split-payment flow | Explain that one receipt must cover the amount due | Display-message regression test |

The retry is only for the standard provider ID lookup; database commits are never automatically retried. There is no image verification API call. Wrong destinations, insufficient amounts, stale receipts, explicit failed receipts, and unsuccessful commits do not become successful payments. Both lookup attempts may consume Veritas credits. Veritas documents this explicitly: https://veritas.et/docs/reference/errors and https://veritas.et/docs/verification.

## Payment method status

| Method | Local protocol + commit test | Real fresh receipt on this app | Required destination configuration / limitation |
|---|---|---|---|
| Telebirr | Pass, including masked wallet and conflicting digits | User confirmed success | Full receiving wallet or merchant account; masked responses only establish visible digits |
| CBE | Pass; legacy suffix and case-sensitive new URL covered | Not confirmed | Full bank account; derive final 8 digits for legacy FT lookup. New token/link supported |
| CBE Birr | Pass | Not confirmed | Valid receiving Ethiopian phone, canonical 251 format |
| Dashen | Pass; numeric scanner reference fixed | Not confirmed | Must match the destination field returned by Veritas; adapter may expose recipient phone rather than a bank account |
| Abyssinia | Pass | Not confirmed | Full account; final 5 digits supplied from trusted business configuration |
| M-Pesa | Pass | Not confirmed | Dedicated endpoint and returned receiver account must match; arbitrary short tills are not proven supported |

Veritas's published provider contract was checked: https://veritas.et/docs/reference/providers. Local provider-shaped fixtures establish integration logic, not bank availability or coverage of every live receipt variant. Fresh receipts and matching configured accounts are needed for the five unconfirmed providers. No invented receipts were submitted to spend subscription credits.

## Remaining gaps and operational findings

- **Owner console unavailable with the current configuration:** OperatorService still uses VERIFY_ME_API_URL pointing to Alet. Alet health returned HTTP 404 in the last live check. Staff verification uses Supabase, but owner login, provisioning and subscription administration need their own deployed replacement backend. They are not fixed by this verification function.
- **Plan activation is manual:** PricingScreen submits a billing support case. It does not collect a subscription payment or automatically activate the requested tier. Existing copy advertising unlimited verifications needs a commercial capacity review because the upstream service uses credits.
- **Split payments are not implemented:** Two receipts cannot currently be combined to cover one amount due. Underpayment instructions now reflect that limit.
- **Excess payment is still treated as a staff tip:** This inherited behavior may not fit deposits, partial invoices or general business overpayments. It needs an explicit product decision and corresponding ledger/UI changes, not a silent change to accounting.
- **Masked destinations have limited evidence:** Two Telebirr wallets with the same visible prefix and last four digits cannot be distinguished using the masked account alone. Stronger proof requires more provider data; a name typed by staff is not independent evidence.
- **Provider outage recovery is bounded:** A long Veritas/bank outage still blocks verification. There is no offline payment approval or background persistent verification queue. A read-only status check can recover an already committed payment after a lost response.
- **Request coalescing/rate limits are per Edge worker:** Database uniqueness prevents a second saved payment for the same business/provider/reference, but different workers can still spend duplicate lookup credits. Durable cross-worker idempotency is a separate database change.
- **Dormant legacy code:** ModernScannerScreen has no active caller. Legacy verifyTransaction/recordVerificationAttempt methods are not used by the active staff flow and refer to retired endpoints/RPCs; they should not be reused without migration.
- **Live tenant administration remains unverified:** Support, deletion requests, password changes, staff CRUD, cashier settlement/rejection, archive reads and tip payouts were traced to their RPCs and their visible states tested where covered. They were not mutated against the user's live business as part of this audit. Static review is not proof of deployed RPC permissions or live end-to-end correctness.
- **Physical camera behavior:** iPhone layout tests do not test camera permission denial, background/resume, OCR accuracy, accessibility at every font size or real receipt photos. These remain device acceptance checks.

## Validation performed

- TypeScript compile passed.
- 47 backend tests passed, including six provider-to-commit fixtures and outage recovery.
- Full Flutter suite passed (59 tests at that run); a subsequent targeted iPhone/client/result suite passed 18 tests, including the added underpayment assertion.
- Flutter analysis: no issues.
- Standalone Edge bundle regenerated with no Node imports, Alet references or private API keys.

After deployment, confirm the function health version and inspect `veritas_lookup` events in Supabase logs when an error recurs. Group by provider, HTTP status and latency before deciding whether another timeout change or provider support escalation is warranted.
