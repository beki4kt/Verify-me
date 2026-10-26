# Chekmi owned receipt verification backend

**26 October 2026.** This Node service is the missing middle layer between
Chekmi's Supabase Edge function and the Ethiopian PHP bank relay. The PHP host
at chekmiverifier.com.et is a bank egress service; it does not serve this
application's /health or /api/internal/provider-lookup routes. The older Alet
URL in README.alet.md returned HTTP 404 for /health and /ready on 26 October.
Neither address is currently a confirmed Node deployment.

## Request path

Flutter → Chekmi Supabase Edge → this Node backend → PHP relay for Telebirr,
M-Pesa and CBE; directly to Dashen, Abyssinia and CBE Birr. The Edge function
validates the staff session, receiving account, amount, date and duplicate,
then commits the financial record. The PHP relay alone does none of those
workspace or database operations. No relay key belongs in Flutter.

## Build and package

Use Node 22.9 or newer. In backend-server:

    npm ci
    npm test
    npm run build

The Dockerfile builds a production image. For a Node ZIP upload on Windows,
run package-alet.ps1 with a new destination under the repository build folder.
The package excludes .env, node_modules and private relay configuration. The
source package includes a compiled dist runtime. The old README.alet.md is
historical; this document and .env.alet.example describe the current route.

## Configure on a separate Node-capable HTTPS host

Start with .env.alet.example as a **name checklist**, not as a file to publish.
Set NODE_ENV=production, CHEKMI_ENV=production, CHEKMI_VERIFIER_MODE=live,
CHEKMI_VERIFICATION_ENGINE=owned and CHEKMI_PROVIDER_EGRESS=proxy. Configure
the project's SUPABASE_URL and server-only SUPABASE_SERVICE_ROLE_KEY. Give
CHEKMI_INTERNAL_LOOKUP_KEY a unique long random value; configure that same
value in the Chekmi Supabase Edge secrets. Configure the three private relay
keys on the Node host, matching the operator's PHP relay configuration:
TELEBIRR_PROXY_KEY, MPESA_PROXY_KEY and CBE_PROXY_KEY. Their bare HTTPS URLs
are already present in .env.alet.example. Never put a key in the mobile build,
the deployment ZIP, logs, or a chat message.

Set CHEKMI_RUN_PREFLIGHT=true. In proxy mode the preflight checks DNS and TLS
for the PHP relay, the three directly contacted banks and Supabase. It does
not submit a receipt, prove key validity or prove that a bank lookup works.
CBE legacy remains dependent on its flaky bank endpoint; disable it with
CBE_LEGACY_ENABLED=false if the current pilot should not expose it.

For a Node ZIP host, install with npm ci --include=dev, build with npm run
build, prune with npm prune --omit=dev, and start with npm start. Configure
the host's public HTTPS reverse proxy and PORT. If using Docker, build the
included Dockerfile. Do not use static-site or PHP-only hosting for Node.

## Read-only acceptance before connecting Supabase

On the new Node hostname, GET /health must return HTTP 200 with status ok.
GET /ready must return HTTP 200 with status ready, verifier engine owned,
and verifierMode live. GET /connectivity must report passed after the proxy
preflight finishes. These are configuration and network checks, not a
successful payment. Run:

    node scripts/check-deployment.mjs https://YOUR-NODE-HOST

It checks unsigned route rejection without a bank reference or financial
write. A 404 on the PHP relay's /health is expected and proves the Node
service has not been deployed at that PHP address.

Only after the Node host passes these checks and a rollout is authorized,
configure the Supabase Edge function with CHEKMI_BACKEND_URL equal to
https://YOUR-NODE-HOST/api, the matching CHEKMI_INTERNAL_LOOKUP_KEY, and
CHEKMI_VERIFICATION_ENGINE=owned. Deploy the tested Edge bundle in a
controlled change. The existing Veritas engine remains live until then.

## Financial acceptance still required

Use an explicitly authorized genuine recent receipt for the Mesob pilot.
Check the configured receiving account, exact amount, provider date,
database commit, duplicate retry, and original-image archive. Test rejection
and cross-workspace access separately. Local test doubles and TLS probes do
not establish live bank correctness. The supplied relay documents give no
redacted real M-Pesa JSON fixture, so its newly supported JSON mapping
remains subject to a genuine response check. Keep the original Veritas bundle
available for rollback; never remove confirmed payment or receipt history.
