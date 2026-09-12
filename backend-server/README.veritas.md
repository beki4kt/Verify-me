# Chekmi: Veritas transaction-ID deployment

This update uses Veritas's standard provider-specific ID verification routes.
The iPhone app retains its native camera and on-device text extraction. Images
may be saved as Chekmi receipt evidence, but are never sent to Veritas. No image
verification credits are used.

## Update the existing Alet app

1. Open the existing Chekmi application in Alet App Hosting. Keep its current
   Supabase and operator environment variables.
2. Upload `Chekmi-Veritas-Backend-20260907.zip` using the same Node upload flow
   as the previous backend. The package root contains package.json.
3. Add/change these environment variables:

   | Name | Value |
   | --- | --- |
   | CHEKMI_VERIFICATION_ENGINE | veritas |
   | VERITAS_API_KEY | Your private Veritas key, entered only in Alet |
   | VERITAS_API_URL | https://verifyapi.leulzenebe.pro |
   | CHEKMI_VERIFIER_MODE | live |
   | CHEKMI_RUN_PREFLIGHT | false |
   | PROVIDER_TIMEOUT_MS | 30000 |
   | ALLOW_LEGACY_VERIFY | false |

4. Retain Node.js 22.9+ or Node 24, port 8080, health path `/health`, and start
   command `npm start`. If Alet asks for a combined install/build command, use
   `npm ci --include=dev && npm run build && npm prune --omit=dev`.
5. Redeploy/restart the application so the updated environment takes effect.
6. Open https://chekmi.app.aletcloud.com/ready. Expect `status: ready`,
   `verifierMode: live`, and inside `verifier`: `engine: veritas`,
   `mode: transaction-id`, `configured: true`, `imageVerification: false`.
   Readiness checks configuration presence, not remaining subscription credits.

The ZIP contains no API keys or database credentials. Do not replace existing
Supabase values with the placeholders in `.env.alet.example`.

## Install and test the iPhone update

Use the new `Chekmi-iPhone.ipa` with AltStore's My Apps > + while AltServer is
reachable. Install over the current app using the same Apple account. Preserve
the existing app and its data; uninstalling is unnecessary for an update.

Sign into the intended business and confirm its receiving accounts in the admin
screen. In Staff > Scan, select the payment provider, capture a fresh payment
receipt, check its transaction ID, enter the amount due and an optional invoice,
order, customer, table, or other reference, then verify.

Check that the amount, business reference, and payment status appear in staff,
cashier, and administrator views. Submitting the same payment again must recover
the original record rather than create a duplicate. A separate receipt with a
wrong destination or insufficient amount must fail. Receipts older than 24 hours
remain rejected; do not reuse an old successful lookup as a freshness test.

## Validation and rollback

Run `npm test` and `npm run build` in the backend directory. Tests use local
upstream/database mocks and consume no paid credits. A single live Telebirr
lookup on September 7 confirmed that the supplied key returned a successful
standard verification response; no database payment was created.

To restore the existing owned provider route, set
`CHEKMI_VERIFICATION_ENGINE=owned` and restart. Its previous bank egress settings
and limitations apply. The app URL, database schema, and staff roles are
compatible with either engine. There is no automatic fallback that could hide
a Veritas access or subscription failure.

Sources: https://veritas.et/docs/getting-started and
https://veritas.et/docs/verification. Provider mappings were checked against
the official https://github.com/Vixen878/verifier-api source.
