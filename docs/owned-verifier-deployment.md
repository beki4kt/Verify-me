# CHEKMI owned verifier deployment

**Current pilot (2026-09-06): Alet App Hosting.** The VPS key-save and console
failed; App Hosting successfully ran the connectivity pilot. Follow
[the App Hosting deployment guide](../backend-server/README.alet.md) for the
backend upload and live receipt tests. M-Pesa's missing intermediate is bundled
with TLS validation preserved. Legacy CBE remains unavailable and is disabled
in the pilot environment. The VPS shortlist below records earlier research;
Ethio Telecom's VPS catalogue was subsequently unavailable to the user.

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
HTTPS reverse proxy in front of Node. For the first low-volume production
deployment, use at least 1 vCPU, 2 GB RAM, Node.js 20 or newer, and a stable
public IPv4 address. Move to 2 vCPU/4 GB if PDF parsing, concurrency, or memory
monitoring shows pressure.

## Ethiopian hosting shortlist (checked 2026-09-05)

The cheapest VPS whose public material clearly confirms Ethiopian hosting is
**AletCloud Nano** at 2,400 ETB/month: 1 vCPU, 1 GB RAM, 10 GB SSD and 1 Mbps.
Use Nano only for the connectivity pilot or very low traffic. The recommended
production starting point is **AletCloud Solo** at 3,200 ETB/month: 1 vCPU,
2 GB RAM, 20 GB SSD and 2 Mbps. VPS usage is hourly with a monthly cap and no
long contract, so CHEKMI can start on Solo and resize to Pro without committing
for a year. Alet says the infrastructure is inside Ethiopia, provides root
access and configurable backups, and identifies its initial region as Ethio
Telecom's Bole core data center.

The public price list does not state the final public-IPv4 charge and says
applicable tax is calculated at checkout. Therefore **3,200 ETB is the base
price, not a guaranteed invoice total**. Confirm the stable public IP, backup
retention, VAT-inclusive total, and SLA on the checkout screen before paying.

Official references:

- [AletCloud VPS](https://aletcloud.com/products/vps/)
- [AletCloud pricing](https://aletcloud.com/pricing/)
- [AletCloud SLA](https://aletcloud.com/legal/sla)

Alet's managed **App Hosting Ultra** is cheaper at 1,440 ETB/month for 1 vCPU
and 1 GiB RAM, with managed builds and TLS. It is not a VPS and does not offer
the same root/network control. It is worth a no-secrets egress preflight only
if Alet confirms that outbound TCP 100 is permitted; do not make it the default
for the verifier until all provider probes and a PDF-memory load test pass.

- [AletCloud App Hosting](https://aletcloud.com/products/app-hosting/)

Lower sticker prices were not accepted as Ethiopian-resident VPS proof:

| Candidate | Public starting price | Decision |
| --- | ---: | --- |
| Ashewa Starter | 2,100 ETB/month | Hold: its company page names US, German and UK data centers and only says regional data is within Africa. Get a sample IP and written Ethiopian-location confirmation. |
| Gojo Host VPS-1 | 2,999 ETB/month | Hold: the company is Ethiopian, but its VPS page does not publicly identify the VM's physical location or outbound country. |
| WebSprix WS-Cloud | Calculator currently shows USD 4.60/month for a sample VM | Quote first: the displayed total and competing 99.99%/99.9% uptime statements must be confirmed in writing. |

- [Ashewa VPS](https://www.ashewacloud.com/vps) and [Ashewa company page](https://www.ashewacloud.com/about-us)
- [Gojo Host VPS](https://gojohost.net/vps/)

Request a written quote from **WebSprix WS-Cloud Elastic** in parallel. Its
public calculator describes self-managed OpenStack, NVMe storage, a selectable
public IP, backups, and 24/7 support. The same page currently shows both 99.99%
and 99.9% uptime language and an unusually low sample total, so neither the
price nor SLA should be treated as contractual until sales confirms them in
writing. Contact `cloudsales@websprix.com` or `+251 115 181901`.

- [WS-Cloud pricing and configuration](https://wscloud.et/pricing)
- [WebSprix cloud overview](https://websprix.com/)

**Ethio Telecom direct cloud** is the established fallback. Its advertised
2-vCPU/4-GB packages include a dedicated public IP, SSH/RDP, weekly backup and
24/7 basic support. The 2 Mbps option starts at 29,644.74 ETB per six months
(about 4,940.79 ETB/month); the 4 Mbps option starts at 37,576.74 ETB per six
months (about 6,262.79 ETB/month). This requires a six-month commitment and the
published backup is only weekly, but the dedicated IP is explicit.

- [Ethio Telecom cloud-server catalogue](https://myportal.ethiotelecom.et/cart.php?gid=35)
- Support: `ETZCloudSupport@ethiotelecom.et`

Wingu and Raxio operate Ethiopian carrier-neutral data centers, but their
public offerings are primarily colocation rather than a small self-service
Linux VPS. They become relevant when CHEKMI needs dedicated hardware or a
managed infrastructure partner, not for the first verifier pilot.

### Purchase gate

Do not point production traffic at any candidate until the provider confirms
all of the following and a temporary instance passes the same checks:

1. The attached IPv4 address is stable, publicly routable, and its **outbound**
   traffic exits through an Ethiopian public IP rather than a foreign NAT or
   proxy.
2. Outbound TCP 443 and TCP 100 are allowed, with working DNS and valid TLS to
   every provider hostname listed below and to the CHEKMI Supabase project.
3. Inbound HTTPS is allowed on TCP 443 and SSH can be restricted to an
   administrator IP or VPN.
4. The provider permits authorized server-side receipt lookups under its
   acceptable-use policy and does not inject an outbound TLS inspection proxy.
5. Snapshot/backup retention, restore time, DDoS response, incident contacts,
   and the applicable uptime SLA are confirmed in writing.

Start with AletCloud Solo and rely on its hourly billing while testing. Before
deploying secrets, use the temporary VPS to record its public IPv4/country and
test DNS, TCP, and TLS connectivity to all six payment-provider endpoints:

```bash
cd backend-server
npm ci
npm run preflight:host -- --supabase-host=YOUR_PROJECT.supabase.co
```

The checked-in preflight requires Ethiopian (`ET`) egress, validates DNS, and
performs a certificate-validating TLS handshake to every provider, including
CBE on TCP 100. Save its output with the hosting decision. Do not use
`--allow-non-et` on the VPS; that switch exists only so developers outside
Ethiopia can diagnose individual endpoints. If any endpoint works only from an
Ethio Telecom network, compare the same matrix on the direct Ethio Telecom VPS
before selecting the final host.

Baseline on 2026-09-05 from the Ethiopian development connection: strict TLS
passed for Telebirr, CBE mobile, Dashen, Abyssinia, CBE Birr and M-Pesa. The
legacy CBE endpoint at `apps.cbe.com.et:100` timed out. This may be endpoint or
network-route specific, so the Alet VPS must pass TCP 100 before CBE is enabled
for production. A timeout is not permission to bypass certificate validation
or silently accept a payment; CHEKMI must return a retryable provider failure.

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

## Ubuntu deployment

Create the VPS with Ubuntu LTS, add an SSH key, and restrict SSH before putting
any secret on it. Install Node.js 20 or newer, npm, Nginx, Certbot, and the
Certbot Nginx integration from trusted OS/vendor repositories. Point the API
domain's `A` record to the VPS. Then place this checkout at `/opt/chekmi` and
run:

```bash
sudo adduser --system --group --home /opt/chekmi chekmi
sudo chown -R chekmi:chekmi /opt/chekmi
cd /opt/chekmi/backend-server
sudo -u chekmi npm ci
sudo -u chekmi npm run build
sudo -u chekmi npm prune --omit=dev

sudo install -d -m 0750 -o root -g chekmi /etc/chekmi
sudoedit /etc/chekmi/verifier.env
sudo chmod 0640 /etc/chekmi/verifier.env
sudo chown root:chekmi /etc/chekmi/verifier.env

sudo install -m 0644 /opt/chekmi/deploy/chekmi-verifier.service \
  /etc/systemd/system/chekmi-verifier.service
sudo systemctl daemon-reload
sudo systemctl enable --now chekmi-verifier
sudo systemctl status chekmi-verifier --no-pager
```

The supplied service runs as the unprivileged `chekmi` account, restarts after
failure/reboot, and adds systemd hardening. It loads secrets only from
`/etc/chekmi/verifier.env`. Keep the Node listener on port 3000 private.

Copy the supplied Nginx configuration, replace `api.example.com` with the real
domain, validate it, and issue the certificate:

```bash
sudo install -m 0644 /opt/chekmi/deploy/nginx-chekmi-verifier.conf \
  /etc/nginx/sites-available/chekmi-verifier
sudoedit /etc/nginx/sites-available/chekmi-verifier
sudo ln -sfn /etc/nginx/sites-available/chekmi-verifier \
  /etc/nginx/sites-enabled/chekmi-verifier
sudo nginx -t
sudo systemctl reload nginx
sudo certbot --nginx -d api.example.com
curl --fail --silent --show-error https://api.example.com/health
curl --fail --silent --show-error https://api.example.com/ready
```

If UFW is used, allow `OpenSSH` before enabling it, allow `Nginx Full`, and do
not open port 3000. Restrict SSH to the administrator's stable IP or VPN when
possible. Confirm automatic certificate renewal with `sudo certbot renew
--dry-run`. Use `journalctl -u chekmi-verifier` for application logs; configure
retention so logs cannot fill the 10-20 GB disk.

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
