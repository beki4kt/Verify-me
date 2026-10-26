# Chekmi capability and verification report — 15 October 2026

## What this build contains

Chekmi is a Flutter iPhone client for organization workspaces. Staff connect a
device with a business code, sign in under a role, and handle verified payments
through a Supabase database. The native iPhone presentation has dark and light
themes, English and Amharic controls, branded payment logos, and layouts tested
at 390 × 844. The AltStore test variant enables all six payment choices and the
protected owner console. The public App Store variant intentionally exposes
Telebirr only and hides demo and owner operations until the remaining providers
pass live acceptance.

| Area | Implemented behavior |
| --- | --- |
| Staff access | Business provisioning, role-based waiter/cashier/admin sign-in, tenant-scoped sessions, logout, and session revocation. |
| Waiter | Camera capture with on-device receipt text extraction or manual reference entry; amount due and optional invoice/order/customer context; payment history, tip balance, and withdrawal requests. |
| Verification | Server-derived destination details, provider receipt lookup, reference/amount/destination/date checks, duplicate prevention, atomic ticket creation, and read-only recovery after an uncertain response. |
| Cashier | Review verified tickets, settle or reject them, and inspect payment history. |
| Business admin | Staff and receiving-account management, password change, payment ledger and receipt evidence, withdrawal review, CSV audit export, support/privacy access, and business deletion request. |
| Owner operations | Protected backend console for business, subscription, support, session, and privacy administration in the test variant; it requires a reachable backend. |
| Demo and plans | Limited demo receipt checks in the test variant; Basic/Pro information and a manual organization plan-request path. No in-app checkout or automatic plan activation. |
| Privacy and support | Published policy URLs, in-app legal consent and support cases, staff account deletion, and client error reporting. |

## Receipt methods and evidence

The source now routes staff and demo Edge lookups through a private Chekmi
backend endpoint. The backend uses `chekmiverifier.com.et` for Telebirr,
M-Pesa, and both CBE receipt formats when hosted outside Ethiopia. It reads
Dashen, Abyssinia, and CBE Birr directly. Relay secrets remain on servers.

| Method | Source route | Local evidence | Live acceptance |
| --- | --- | --- | --- |
| Telebirr | Ethiopian relay, normalized JSON | Parser, relay route, private endpoint, and payment commit tests pass | Fresh real receipt still required |
| CBE legacy | Ethiopian relay, JSON or PDF | JSON relay contract and fail-closed tests pass | Upstream port-100 reliability and fresh receipt still required |
| CBE new | Ethiopian relay, JSON | New-token parsing and destination checks pass | Fresh valid token still required |
| M-Pesa | Ethiopian relay, Safaricom JSON containing receipt PDF | PDF parser and six-provider commit fixture pass | Fresh real receipt still required |
| Dashen | Direct receipt PDF | PDF parser and six-provider commit fixture pass | Fresh real receipt still required |
| Abyssinia | Direct receipt JSON | Suffix/destination checks and six-provider commit fixture pass | Fresh real receipt still required |
| CBE Birr | Direct receipt PDF | PDF parser, phone derivation, and six-provider commit fixture pass | Fresh real receipt still required |

The backend suite passed **54/54 tests**. Flutter analysis found no issues; the
full Flutter suite, production variant checks, and iPhone layout suite passed.
These tests exercise controlled provider responses. They do not prove that a
current bank receipt will verify in production.

## Live service and speed check

On 15 October 2026, the live `chekmi-verify` GET endpoint returned HTTP 200 in
about **0.75 s**, but its response still reported `engine: veritas` and version
`2026-09-08.2`. The configured Alet backend `/ready` returned HTTP 404 in about
**0.63 s**. The relay host answered over verified HTTPS in about **0.91 s** with
the expected missing-key response. These are reachability measurements, **not
receipt-verification timings**. No authenticated fresh receipt or relay status
key was available for an end-to-end speed measurement.

The staff client allows 60 seconds for a verification request. The Edge
function has a 45-second overall deadline and can retry a transient lookup
once. The example backend provider timeout is 30 seconds. Actual customer
response time depends on bank and relay latency and must be measured with fresh
receipts after deployment. A completed payment is reported only after the
database returns a saved ticket ID.

## Current build status

An unsigned native iPhone IPA is built through the repository's macOS AltStore
workflow. It can be installed only after AltStore signs it with an Apple
account. It is a test build with all six methods visible, not an App Store
submission. The new server route is in the build source, but the deployed
Supabase function and backend have not yet been switched to it; the IPA will
reach the existing function until that server deployment is complete.

The [macOS build run](https://github.com/beki4kt/Verify-me/actions/runs/38722388085)
packaged source commit `a42082383e1e1562636a03db598b82d8a7054458` as build
`8`. The downloaded file is `build/iphone-relay-20261015/Chekmi-iPhone.ipa`
(24,256,913 bytes), with SHA-256
`aa789ae53b6151a294938d4a6dfb7276587eff9c3d7dc5147f87ca1d38acf6f0`.
The checksum matches the workflow's `.sha256` file; the downloaded artifact ZIP
matches GitHub's published digest. The IPA contains an ARM64 Runner binary,
`Info.plist`, app icon, launch screen, and privacy manifests. Installation and
on-device behavior remain untested here.
