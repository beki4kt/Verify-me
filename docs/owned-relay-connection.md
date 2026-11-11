# Chekmi owned verification gateway

Chekmi's backend performs provider receipt fetches and parsing. For an overseas
backend, Telebirr, M-Pesa, and CBE use the Ethiopian relays described in
`CONNECT-VERIFY-ME.md`; Dashen, Abyssinia, and CBE Birr are fetched directly.
The Flutter app never receives relay keys. Staff and demo Supabase functions
send a private server-to-server lookup to the Chekmi backend, then retain their
existing session, quota, destination, freshness, and payment commit checks.

## Backend settings

Use `backend-server/.env.alet.example` as the production template. Set
`CHEKMI_VERIFICATION_ENGINE=owned` and `CHEKMI_PROVIDER_EGRESS=proxy` when the
backend is outside Ethiopia. Configure these endpoint URLs:

```env
TELEBIRR_PROXY_URLS=https://chekmiverifier.com.et/verify.php
MPESA_PROXY_URL=https://chekmiverifier.com.et/mpesa.php
CBE_PROXY_URL=https://chekmiverifier.com.et/verifyCbe.php
```

Set their corresponding `TELEBIRR_PROXY_KEY`, `MPESA_PROXY_KEY`, and
`CBE_PROXY_KEY` privately from the relay host's matching keys. Generate a
separate long random `CHEKMI_INTERNAL_LOOKUP_KEY` for the backend-to-Edge
contract. Keep all four values on servers only. The backend's `/ready` returns
503 if proxy mode lacks any of the three relay pairs.

`CBE_APP_ID` and `CBE_APP_VERSION` can remain empty in proxy mode because the
relay supplies them. `CBE_LEGACY_ENABLED=true` permits legacy receipts, but the
upstream port-100 service can still fail. The backend accepts both PDF and
normalized JSON from the CBE legacy relay and rejects incomplete receipts.

## Supabase function settings

Add these secrets to the same Supabase project that hosts `chekmi-verify` and
`chekmi-demo`:

```env
CHEKMI_BACKEND_URL=https://YOUR_BACKEND_HOST/api
CHEKMI_INTERNAL_LOOKUP_KEY=<same private value as the backend>
```

Keep `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` configured for the trusted
database RPCs. `VERITAS_API_KEY` is no longer needed by these functions. Build
the functions from `backend-server` with `node scripts/build-edge.cjs` and
`node scripts/build-demo.cjs`, then deploy both with JWT verification disabled
as described in `docs/supabase-verification.md`. The functions validate staff
sessions or demo installation tokens themselves.

The release configuration may keep `CHEKMI_VERIFICATION_URL` pointed to the
Supabase staff function while `VERIFY_ME_API_URL` points to the Chekmi backend
for owner operations. The staff function's GET response should report
`engine: owned`; its private lookup must reach `/api/internal/provider-lookup`
with the matching key. Do not test with a real receipt until the backend
`/ready` response reports `configured: true` and the relay's own operator
diagnostic confirms the upstream banks are reachable.
