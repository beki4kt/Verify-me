# Chekmi relay handoff — 26 October 2026

**For the developer who built the PHP bank relay.** Chekmi's payment implementation is locally prepared, but the new Node service has not started and no new bank payment has been verified through it. Please work on the hosting and relay connection below; leave the existing PHP relay and payment records intact.

## Where we stopped

- The PHP relay at `chekmiverifier.com.et` provides Telebirr (`/verify.php`), M-Pesa (`/mpesa.php`), and CBE (`/verifyCbe.php`). It is a bank egress service, **not** the Chekmi Node API.
- The Chekmi path is Flutter → Supabase `chekmi-verify` → private Node `/api/internal/provider-lookup` → PHP relay/direct bank endpoints. Supabase performs session, receiving-account, amount, freshness, duplicate, and financial-commit checks.
- We prepared and locally tested the Node backend against the two relay documents. M-Pesa JSON `base64Data` and older PDF responses, Telebirr Amharic success/error replies, and CBE token errors have local tests. They still need a genuine authorized provider response before we can claim live compatibility.
- The owner uploaded and extracted `Chekmi-Backend-Plesk-20261026.zip` into the **separate** Plesk subdomain `api.chekmiverifier.com.et/chekmi-node`. The Node app is not enabled. The existing PHP domain's `/httpdocs` must remain untouched.
- Let's Encrypt failed for `api.chekmiverifier.com.et` with `acme:error:dns`: public A and AAAA lookups timed out. On 26 October, Google DNS returned `SERVFAIL` with “Name servers did not respond [213.55.96.152]”; Cloudflare returned “No Reachable Authority at delegation chekmiverifier.com.et.” A local cached A record does not resolve this public-authority failure. The parent relay domain may also be intermittently unreachable to uncached clients.

## Your next move

1. Ask Ethio Telecom/Plesk DNS support to repair authoritative DNS/delegation and ensure the authoritative server answers external UDP and TCP port 53 for `chekmiverifier.com.et`. Confirm public resolvers return the intended A record for both the parent and `api` names. Remove or correct any unintended AAAA record. The authoritative DNS issue must be fixed before retrying certificate issuance; changing the ZIP cannot fix it.
2. Issue and assign a valid certificate to **`api.chekmiverifier.com.et`**. Check the PHP relay domain still serves HTTPS correctly.
3. In the **API subdomain's** Node.js panel, set application root to `chekmi-node`, document root to its `public` directory, startup file to `app.js`, Node 22.9+, production mode, and npm. Add only the variable names listed in [`backend-server/.env.plesk.example`](../../backend-server/.env.plesk.example), supplying values privately in Plesk. Do not set a fixed `PORT`. Run NPM Install and enable Node.js. Never send keys in chat or place a real `.env` under the public root.
4. Run read-only checks: `https://api.chekmiverifier.com.et/health`, `/ready`, `/connectivity`, and `node backend-server/scripts/check-deployment.mjs https://api.chekmiverifier.com.et`. `/ready` should report `owned` and `live`; the unsigned private lookup route must reject access. These checks submit no receipt.
5. Share **status codes and sanitized response fields only**. We will then review the controlled Supabase Edge switch and a genuine, authorized MESOB-DEMO receipt test together. Do not switch the Edge engine or run a real payment on your own.

## What remains on our side

The deployed Supabase verifier still reports **Veritas**, the receipt-evidence endpoint rejects unsigned access as expected, and `chekmi-demo` returned 404 at the last check. The owned Node-to-relay switch, future-tip migration, original-image upload/retrieval, duplicate retry, and cross-workspace acceptance are **not live-proven**. Local backend tests passed (75/75 on 27 October), including lost upload response, conflicting object recovery and archived-original immutability; proxy preflight tests passed (3/3), and backend type-check passed. These tests use doubles. The current evidence and rollout notes are in [`PHASE_2_PAYMENT_EVIDENCE_REPORT.md`](PHASE_2_PAYMENT_EVIDENCE_REPORT.md) and [`backend-server/README.plesk.md`](../../backend-server/README.plesk.md).

**Please send back:** public DNS result, certificate status, Node `/health` and `/ready` responses, `/connectivity` status, and any Plesk startup error with secrets removed.
