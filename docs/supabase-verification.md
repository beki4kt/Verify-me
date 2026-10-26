# Staff payment verification through Chekmi's owned gateway

The active staff path is iPhone -> `chekmi-verify` Supabase Edge Function ->
Chekmi backend -> bank receipt endpoint (using an Ethiopian relay where needed)
-> atomic payment commit in Supabase. The app sends a receipt reference and the
amount due; the backend fetches provider evidence. The receipt image stays in
Chekmi's payment workflow and is not sent to a third-party verification API.

The Edge Function validates the opaque staff session with the trusted
`get_verification_context` RPC before looking up a receipt. It derives the
CBE/Abyssinia suffix or CBE Birr phone from the configured business account,
checks the returned destination, amount, and receipt age, then commits with
`commit_verified_payment`. A status request only checks for an existing saved
payment and never calls a provider.

Configure the backend and relay keys using [owned-relay-connection.md](owned-relay-connection.md).
Set `CHEKMI_BACKEND_URL` and `CHEKMI_INTERNAL_LOOKUP_KEY` in Supabase Edge Function
secrets. The latter must match the backend value and must never be built into
Flutter. Supabase also supplies `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.

Build from `backend-server`:

```powershell
node scripts/build-edge.cjs
node scripts/build-demo.cjs
```

Deploy `chekmi-verify` and `chekmi-demo` from `supabase/functions`. Keep legacy
JWT verification disabled for these functions because Chekmi uses its own staff
sessions and demo installation tokens. The functions enforce those credentials
through trusted database RPCs.

```powershell
supabase functions deploy chekmi-verify --project-ref lpbdxtzyzlaioggefscc --no-verify-jwt
supabase functions deploy chekmi-demo --project-ref lpbdxtzyzlaioggefscc --no-verify-jwt
```

Before a live receipt test, check the backend `/ready` endpoint for
`verifier.engine: owned` and `verifier.configured: true`. The staff function GET
endpoint should report `engine: owned` and version `2026-10-15.1`. A 401 on
that GET means the Supabase JWT gateway is still enabled; a 503 means required
function secrets are missing. After a real fresh receipt, confirm a saved
ticket appears in staff and cashier views. A receipt older than 24 hours is
rejected by the existing freshness rule.
