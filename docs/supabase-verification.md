# Alet-free staff payment verification

The September 7 screenshot showed a timeout. A subsequent live check returned
HTTP 404 with an AletCloud HTML page from the configured Alet API. This was not
a Veritas transaction rejection. The receipt shown, DHU5AM9UB3, is dated August
30 and remains too old for a new payment under the 24-hour acceptance policy.

The new payment path is iPhone -> Supabase Edge Function -> Veritas transaction
ID lookup -> atomic payment commit in the existing Supabase database. Alet is
not contacted by this verification function. The Veritas API key stays in
Supabase secrets. Camera text extraction continues on the iPhone; Veritas never
receives the receipt image.

## One-time deployment in Supabase

1. Open https://supabase.com/dashboard/project/lpbdxtzyzlaioggefscc/functions.
2. Create a new Edge Function using the dashboard editor. Name it exactly
   `chekmi-verify`.
3. Replace the sample code with the complete contents of the supplied `index.js`.
   It is a standalone JavaScript bundle with no external dependencies. If the
   editor uses an `index.ts` tab, the same JavaScript code is valid there.
4. Deploy the function. In its settings, turn OFF **Verify JWT with legacy
   secret** (also called **Enforce JWT verification**). Chekmi uses opaque staff
   sessions rather than Supabase Auth JWTs; the function authenticates every
   payment/status request through the existing trusted `get_verification_context`
   RPC. Disabling the JWT gateway does not bypass this staff authentication.
5. In Edge Functions -> Secrets, add `VERITAS_API_KEY` with your supplied key.
   Supabase supplies `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` automatically.
   Do not put any private key in the mobile app or function source.
6. Open https://lpbdxtzyzlaioggefscc.supabase.co/functions/v1/chekmi-verify.
   It should return `status: ready`, `service: chekmi-verify`, version
   `2026-09-07.1`, and `engine: veritas`. HTTP 401 here means the JWT gateway is
   still enabled; `not_ready` means a required secret is missing; HTTP 404 means
   the function has not been deployed under the correct project/name.

CLI alternative (requires a Supabase login with deployment access):

```powershell
supabase functions deploy chekmi-verify --project-ref lpbdxtzyzlaioggefscc --no-verify-jwt
```

## Install the matching iPhone build

Use the IPA provided with this deployment file. Older builds still point at
Alet. Move it to iPhone Files, keep AltServer reachable, and use AltStore ->
My Apps -> +. Install with the same Apple account over the existing app.

Sign into your business, select Staff -> Scan, scan a fresh receipt, check the
transaction ID and amount due, and verify. The receiving account must be set in
Admin and match the payment. Invoice/order/customer context is optional. Check
the resulting payment in staff and cashier views. Retrying a saved receipt
returns the existing payment; an HTTP 200 without a saved ticket ID never
triggers a success animation.

After a timeout or uncertain commit, the app makes one read-only status request.
That request uses no Veritas credit and cannot create a payment. If no saved
confirmation is available, the app reports the uncertainty instead of claiming
it is still checking indefinitely. Wrong destination, insufficient amount, old
receipt, missing deployment, and upstream outages have distinct error messages.

This change moves staff verification off Alet. The separate platform-owner
console retains its configured backend URL; do not delete that hosting app if
you still need its operator-only endpoints. Ordinary business/staff data remains
in the existing Supabase project, with no database migration for this change.

## Source and validation

Edit `backend-server/src/edgeVerification.ts` or the shared `veritasProtocol.ts`,
then run `node scripts/build-edge.cjs` inside backend-server to regenerate
`supabase/functions/chekmi-verify/index.js`.

Backend tests cover authorization, immutable commit confirmation, recovery,
concurrent requests, destination checks, amount checks, receipt age, and provider
failures. Client tests cover HTML responses, false HTTP 200 results, missing
deployments, and timeout recovery. Actual camera operation and a fresh payment
still require testing on the physical iPhone after function deployment.

References:
- https://supabase.com/docs/guides/functions/deploy
- https://supabase.com/docs/guides/functions/auth-headers
- https://veritas.et/docs/verification
