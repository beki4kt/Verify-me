# Dedicated demo scanner and connected-business login

## Behavior

Live demo now opens six payment methods directly. Selecting one opens demo scan mode with native camera/OCR on iPhone and Android and manual entry as a fallback. It does not log into the shared demo staff account, navigate to a staff dashboard, change the current staff session, create a ticket or move money.

Each installation has 10 free provider lookup attempts, persisted on the server. A successful lookup shows the actual provider receipt amount, reference, date and recipient details. The result explicitly says it is a demo and not a recorded business payment. Failed provider lookups also consume an attempt; invalid local input and read-only usage/status requests do not. A timeout triggers a status read rather than another paid lookup.

The allowance uses a random token stored on the installation, not a signed-in identity. Reopening the app or changing a connected business does not refill it. Clearing app storage/reinstalling can create a new installation. This is an installation allowance, not a tamper-proof ten-per-person limit. A shared daily capacity defaults to 100 lookup attempts to bound the private API credit exposure; set `DEMO_DAILY_LIMIT` on the function to change it (1–10000). Public account-based trials would require a separate identity flow.

The database reserves usage with row locks and a unique request ID before calling Veritas. Replaying the same request ID returns the existing result/pending status without another lookup. The client displays the server's remaining count, never a local success counter. Requests are stored separately from financial records. The generated function contains no Veritas key or demo staff credentials.

CBE/Abyssinia demo receipts require the receiving bank account for their provider lookup suffix; CBE Birr requires the receiving phone. These values are lookup inputs in an unbound demo. The result does not establish that a receipt paid any connected business. Real staff verification continues to enforce trusted destination/amount/freshness rules through the existing `chekmi-verify` function.

The connected-business login begins with the business code and name, followed immediately by the credentials. Decorative hero copy, role chips, field instructions, and access guidance have been removed. The panel uses a layered cyan-to-violet border, elevated shadow, focus glow, hover lift, animated error/loading states, and a password reveal control. It responds to narrow phone layouts and desktop widths, supports both +2519 and +2517 prefixes, and respects reduced motion. Concise product copy is now the default across the app; operational errors, confirmations, and legal text remain explicit.

## Install

1. In the Supabase project's SQL Editor, run `demo-setup.sql` supplied with the release (source: `supabase/migrations/202609080001_demo_verifications.sql`). It creates isolated demo quota/result tables and service-only RPCs; it does not seed a business or known staff credentials.
2. Create a NEW Edge Function named **chekmi-demo**. Paste the complete `demo-index.js` file into its entry file and deploy.
3. Disable **Verify JWT with legacy secret** for this demo function. Its public API uses an installation token with a server-enforced quota, not Supabase Auth or staff JWTs. Keep the existing `chekmi-verify` function unchanged.
4. Keep `VERITAS_API_KEY` in Supabase secrets. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are supplied by Supabase. Optionally set `DEMO_DAILY_LIMIT` to the desired shared daily trial capacity; default 100.
5. Confirm `https://lpbdxtzyzlaioggefscc.supabase.co/functions/v1/chekmi-demo` reports `status: ready`, `version: 2026-09-08.1`. Readiness checks configuration only; the first usage call also checks the demo database functions.
6. Install the accompanying IPA using AltStore -> My Apps -> + with the same Apple account. Open Live demo and confirm the payment-method picker and remaining allowance. Choose a provider, scan a fresh receipt, and check the actual result. Connect a business separately to review the redesigned login.

For browser previews, add their exact origins to `CORS_ALLOWED_ORIGINS` on the function. Native iPhone requests have no browser Origin and do not require this setting.

## Verification and limits

Backend tests exercise actual receipt normalization, quota-denied handling, request replay, status-only recovery, no staff/financial RPCs and a daily-capacity denial. Flutter tests exercise the dedicated navigation, exhausted UI state, timeout recovery, login/password/error interactions, narrow phone layout and reduced motion.

The PostgreSQL migration has been reviewed but cannot be executed against this project without deployment access; mocked RPC tests are not proof of the deployed database. Physical camera behavior and a real demo lookup still require acceptance testing after deployment. SQL uses service-only functions and explicit row locks; verify the 11th request is denied after setup. No live demo lookup was performed during local testing.
