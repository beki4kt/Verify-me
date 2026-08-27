# CHEKMI owned verifier deployment

CHEKMI no longer calls the external `verifyapi.leulzenebe.pro` route. The
TypeScript backend fetches and parses provider receipts itself, then keeps the
existing authenticated verification pipeline:

1. Validate the opaque staff session and load the restaurant's receiving
   account from Supabase.
2. Fetch the provider receipt through direct Ethiopian egress or a configured
   private relay.
3. Validate the provider status, destination, amount, reference, and payment
   time on the server.
4. Atomically commit immutable evidence and the waiter ticket through the
   service-role RPC.

The Flutter client never receives a provider credential, relay secret, or
Supabase service-role key.

## Recommended production topology

For all six providers, deploy the complete `backend-server` on infrastructure
whose outbound traffic uses an Ethiopian public IP. Use a stable domain and
HTTPS reverse proxy in front of Node. A practical starting size is 2 vCPU,
2 GB RAM, Node.js 20 or newer, and a static IPv4 address.

The host must be able to make outbound HTTPS requests to:

- `transactioninfo.ethiotelecom.et` (Telebirr)
- `apps.cbe.com.et:100` and `mb.cbe.com.et` (CBE)
- `receipt.dashensuperapp.com` (Dashen)
- `cs.bankofabyssinia.com` (Bank of Abyssinia)
- `cbepay1.cbe.com.et` (CBE Birr)
- `m-pesabusiness.safaricom.et` (M-Pesa)
- the CHEKMI Supabase project

Do not disable TLS certificate verification. If a provider cannot present a
valid certificate chain, use a controlled relay that validates the provider
connection correctly or pause that provider until the issue is resolved.

## Required backend configuration

Create `backend-server/.env` from `.env.example`. Production requires:

```dotenv
NODE_ENV=production
CHEKMI_ENV=production
CHEKMI_VERIFIER_MODE=live
CHEKMI_PROVIDER_EGRESS=direct
PROVIDER_TIMEOUT_MS=20000

SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=YOUR_BACKEND_ONLY_SERVICE_ROLE_KEY

CORS_ALLOWED_ORIGINS=https://YOUR_APP_DOMAIN
VERIFY_RATE_LIMIT_PER_MINUTE=20

OPERATOR_EMAIL=...
OPERATOR_PASSWORD_HASH=...
OPERATOR_TOTP_SECRET=...
OPERATOR_SESSION_SECRET=...
```

New-format CBE tokens additionally require current, authorized values for:

```dotenv
CBE_APP_ID=...
CBE_APP_VERSION=...
```

Obtain those values through an authorized CBE integration or permitted testing
process. The values bundled in the supplied verifier-core archive are treated
as stale and are not copied into CHEKMI.

Install and start the production backend from the deployed checkout:

```powershell
cd backend-server
npm ci
npm run build
npm start
```

Run `npm start` under a service supervisor so it restarts after failures and
server reboots. Terminate public TLS at a reverse proxy, forward only to the
local Node port, and do not expose `.env` or the Node port directly.

Point the client at the new route by copying `config/production.example.json`
to the ignored `config/production.json` and setting:

```json
{
  "CHEKMI_ENV": "production",
  "VERIFY_ME_API_URL": "https://YOUR-CHEKMI-API.example/api",
  "CHEKMI_SUPABASE_URL": "https://YOUR_PROJECT.supabase.co",
  "CHEKMI_SUPABASE_PUBLISHABLE_KEY": "YOUR_PUBLIC_PUBLISHABLE_KEY"
}
```

Only the publishable Supabase key belongs in this client file. The service-role
key and every provider/relay credential remain on the backend.

## Foreign host plus Ethiopian relays

If the main CHEKMI server must remain outside Ethiopia, set
`CHEKMI_PROVIDER_EGRESS=auto` and configure private Ethiopian relay URLs and
new random keys:

```dotenv
TELEBIRR_PROXY_URLS=https://relay.example.et/verify.php
TELEBIRR_PROXY_KEY=...
CBE_PROXY_URL=https://relay.example.et/verifyCbe.php
CBE_PROXY_KEY=...
MPESA_PROXY_URL=https://relay.example.et/mpesa.php
MPESA_PROXY_KEY=...
```

The supplied relay scripts cover Telebirr, CBE, and M-Pesa only. Dashen,
Abyssinia, and CBE Birr still make direct calls, so this topology is not a full
six-provider solution until equivalent private relays are built and tested.
Running the complete backend in Ethiopia is therefore the recommended path.

The proxy keys embedded in the received verifier-core archive and its deploy
notes must be considered exposed. Generate new independent random keys before
deploying; do not reuse or commit the supplied values. Restrict relay ingress
to the main backend IP where possible, add rate limits, and never log query
strings containing relay credentials.

## Database requirements

Apply all Supabase migrations in repository order. Production must have the
backend-only service-role key because `get_verification_context`, duplicate
recovery, failed-attempt audit, and `commit_verified_payment` are intentionally
not executable by anonymous clients.

Use `supabase/seed.sql` only in local or staging environments. Never deploy the
known `MESOB-DEMO` credentials to production.

## Acceptance checklist

Before enabling a provider for restaurants:

1. Confirm `/health` returns `200` and `/ready` returns `200` without exposing
   secrets.
2. From the production host, verify DNS, TLS, and response time for every
   provider hostname.
3. Configure the exact restaurant receiving account for each provider.
4. Run one recent, low-value real payment per provider and confirm payer,
   destination, amount, reference, successful status, and timestamp.
5. Confirm an underpayment, wrong destination, stale payment, duplicate
   reference, invalid staff session, and provider timeout are all rejected.
6. Confirm logs contain request IDs and status codes but no names, phone
   numbers, bank accounts, receipt HTML, PDFs, or relay secrets.
7. Add uptime alerts and daily synthetic checks that do not create tickets.

These receipt endpoints are unofficial scraping integrations and can change
without notice. Written provider approval or an official merchant API is the
best long-term route. Review Ethiopian financial, privacy, retention, and
consumer-protection obligations with qualified local counsel before production.
