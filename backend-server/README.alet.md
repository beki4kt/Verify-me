# Deploy CHEKMI backend to Alet App Hosting

**September 7 update:** for the Veritas Pro transaction-ID integration, follow
[README.veritas.md](README.veritas.md). The guide below describes the previous
owned-verifier deployment and its bank egress diagnostics.

Prepared 2026-09-06. This package is the real Express API, replacing the earlier
connectivity-only app. It has no Supabase service key, operator secret or live
receipt. Keep the current test ZIP available for rollback.

## What is fixed and what is pending

- Telebirr's nested bilingual receipt layout and three-column invoice section
  are now parsed without treating headers or ancestor table text as values.
  The provider must supply its own matching invoice reference. A live receipt
  parsed successfully; an old receipt still fails the 24-hour freshness policy.
- M-Pesa omitted its intermediate certificate. The package supplies the official
  DigiCert intermediate only for the M-Pesa hostname. Its fingerprint and issuer
  signature are verified locally. TLS expiry, hostname and chain verification
  remain enabled. A live local TLS test passed after this change.
- Legacy CBE at apps.cbe.com.et:100 remains unreachable. CBE_LEGACY_ENABLED=false
  returns a retryable 503 without contacting that path. This is containment, not
  a claim that the old bank service is repaired.
- New CBE uses mb.cbe.com.et and is independent of the legacy switch. It still
  requires valid CBE_APP_ID/CBE_APP_VERSION headers and a genuine new-format
  receipt. Do not guess header values or claim TLS success proves receipt access.
- Internal HTTP /health works behind Alet's TLS proxy. All other routes retain
  the production HTTPS requirement.
- /connectivity serves cached startup DNS/TLS diagnostics; refreshing never
  runs additional bank requests. SKIP is distinct from PASS.

## Upload and configure

Open your existing chekmi app in Alet's Apps area. Upload the backend ZIP using
the same Node deployment flow that worked for the connectivity pilot, then set:

| Setting | Value |
| --- | --- |
| Runtime | Node.js 22.9+ (current Node 22 LTS), or Node 24 |
| Root directory | blank or . (package files are at the ZIP root) |
| Install/build command | npm ci --include=dev && npm run build && npm prune --omit=dev |
| Start command | npm start |
| Port, if requested | 8080 (the backend honors Alet's PORT variable) |
| Health path | /health |

If the UI supplies a separate install command, use npm ci --include=dev there;
then build with npm run build && npm prune --omit=dev. Including development
dependencies during build is required for TypeScript even with NODE_ENV=production.
For Docker deployments, use the included Dockerfile with this ZIP as its context.
The precompiled dist files are also included for Node upload flows that only
install production dependencies and start the app. Do not use static-site mode.

For one-at-a-time pilot tests, use the free plan if the build/runtime fits.
It has only 256 MiB and sleeps when idle. For the first receipt/PDF pilot I would
choose App Hosting Ultra (1 GiB, listed 1,440 ETB/month before checkout tax), then
measure memory and concurrency. Production capacity and availability are not
established by a successful pilot. Do not choose VPS Solo by mistake.

Copy the NONSECRET settings from .env.alet.example into Alet's environment form.
SUPABASE_URL is the project already used by this checkout. Change it if you are
using a separate test project. Set SUPABASE_SERVICE_ROLE_KEY privately in Alet
from that same Supabase project's backend API keys. Never use the client anon/
publishable key for this field or paste the service key into chat.

CORS_ALLOWED_ORIGINS is a comma-separated list of actual browser app origins,
without a path or trailing slash. The provided localhost origins support the
usual local web preview. Add the actual LAN origin for an iPhone browser preview.
Native iPhone/Android requests do not require a browser origin entry.

Leave VERIFY_API_KEY and provider URL/relay overrides unset. Keep
ALLOW_LEGACY_VERIFY=false and CHEKMI_VERIFIER_MODE=live. The authenticated staff
workflow is POST /api/verify-and-create. The old public /api/verify stays disabled.

The owner console is separately configured with OPERATOR_EMAIL,
OPERATOR_PASSWORD_HASH, OPERATOR_TOTP_SECRET and OPERATOR_SESSION_SECRET.
They are not required for staff verification, and the owner login remains
unavailable until correctly configured. The backend's operator:setup script can
prepare them locally; do not reuse the old development password or static MFA.

Save environment variables and redeploy/restart; Alet applies them at that point.

## Check the hosted backend

1. https://chekmi.app.aletcloud.com/health should return status ok.
2. /ready should return HTTP 200, status ready, verifierMode live. This checks
   configuration presence, not whether the service key or database schema works.
3. Wait up to 150 seconds, then open /connectivity. Expect Ethiopian egress,
   enabled provider TLS checks and Supabase TLS to pass. Legacy CBE should say SKIP.
4. From this backend folder run:

   node scripts/check-deployment.mjs https://chekmi.app.aletcloud.com

   This checks health, config and unauthenticated route rejection, without
   submitting receipts or creating payments. A root-page 404 is normal for this API.

If /ready is 503, check the Supabase variables and egress setting. If /health
does not return the expected JSON, inspect the build/runtime logs. If M-Pesa
fails again, preserve the exact error. Its observed serving certificate expires
September 17, 2026; Safaricom must renew it. Do not disable verification.

## Connect Flutter and test real payments

Set these public Flutter build values:

- VERIFY_ME_API_URL=https://chekmi.app.aletcloud.com/api
- CHEKMI_ENV=production
- CHEKMI_SUPABASE_URL=https://lpbdxtzyzlaioggefscc.supabase.co
- CHEKMI_SUPABASE_PUBLISHABLE_KEY=the same project's client publishable/anon key

Use config/production.example.json in the main repo as a starting point and
save local public build settings as config/production.json, which is ignored.
For a browser build from the main repo:

    flutter build web --release --dart-define-from-file=config/production.json

For the iPhone UI variant also include --dart-define=CHEKMI_IPHONE_UI=true.
Serve build/web using the project's existing local preview workflow. Rebuilding
is necessary: changing an Alet setting cannot change an already compiled app URL.

Use a dedicated test business/staff login, configured with receiving accounts
that match the real receipts you are authorized to verify. These live tests
write real verification evidence and tickets to that business. Use receipts
within the configured 24-hour window; do not weaken freshness checks for old ones.

Test Telebirr, Dashen, Abyssinia, CBE Birr, then M-Pesa, one at a time. Test new
CBE only after its public receipt integration headers are configured. For each:

1. Scan or enter a fresh genuine receipt and its actual amount. Confirm the
   ticket, amount, receiving account and waiter/cashier view agree with the bank.
2. Submit the same receipt again: it must not create another payment/ticket.
3. Use separate uncommitted test receipts to check an expected amount greater
   than the paid amount and a receipt to a different destination. Both must be
   rejected without creating a verified ticket. A previously committed receipt
   may take the idempotent return path and is not suitable for these checks.
4. Check a legacy FT CBE receipt with legacy disabled: it must stay unverified
   with an unavailable response. Never treat a provider error as success.

If Supabase reports a missing RPC/table, first inspect the project's installed
migrations against supabase/migrations. Do not blindly run reset/setup SQL over
an existing business database. The authenticated context, evidence commit and
duplicate protection must all work before production acceptance.

## Sources

- https://aletcloud.com/docs/app-hosting/
- https://aletcloud.com/docs/deploy-app/
- https://aletcloud.com/pricing/
- certs/README.md (certificate source, fingerprint and expiry)
