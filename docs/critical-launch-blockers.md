# CHEKMI Critical Launch Blockers

These items were identified during the August 10, 2026 product-readiness audit.
This is the implementation tracker for the seven launch workstreams.

## 1. Server-authoritative payment verification

**Status: implemented locally on August 12, 2026; migration, deployment, and live-provider acceptance testing remain.**

- Replace the client-controlled verify/check/create sequence with one authenticated, atomic server operation.
- Validate the staff session, role, tenant, amount, destination account, provider result, and duplicate reference on the server.
- Match the receiving account for every supported provider, not only Telebirr and CBE.
- Create the immutable verification evidence, audit entry, and ticket in the same transaction.

## 2. Authentication and authorization hardening

**Status: partial.** Hard-coded/plaintext super-admin access was removed; the
public operator screen is sealed; tenant/staff access is token/role protected;
passwords are hashed; login lockout, session listing/revocation foundations,
and security audit logging are implemented. MFA and password-recovery delivery
still require an email/SMS identity provider and protected operator console.

- Remove the hard-coded `MASTER99` super-admin path.
- Replace the client-side super-admin password lookup with hashed server-side authentication, MFA, and audit logging.
- Add login rate limiting, temporary lockout, password recovery/reset, session-expiry UX, and device/session management.
- Move tenant, staff, payment-account, and subscription mutations behind role-protected RPCs or backend endpoints.
- Replace the optional global verifier API key with staff/tenant-aware server authentication.

## 3. Accurate and immutable financial records

**Status: implemented locally.** Expected/verified amounts, tips, provider
metadata and receipt evidence are immutable; settlement and exception actions
append actor/reason events; payout requests have pending/approved/paid ledger
states; reports query server-side date/staff/provider ranges without the old
100-ticket limit.

- Store expected amount, verified amount, original tip, provider timestamp, payer/receiver data, and verification evidence.
- Record the actor, timestamp, and reason for every settlement, rejection, void, refund, or dispute.
- Prevent the cashier from replacing verified bank data with an unrelated manually entered amount.
- Add a proper waiter tip-payout ledger with pending, approved, and paid states.
- Replace last-100-ticket dashboard math with server-side date-range reports and accurate totals.

## 4. Safe offline synchronization

**Status: secure online-only architecture implemented locally.** Verification
and financial commits require connectivity and are never queued or replayed.
Legacy client-authored records remain quarantined with a visible count until a
user explicitly acknowledges them; they cannot migrate to another session.

- Bind every queued record to its original tenant, staff member, and verification evidence.
- Prevent a queued ticket from syncing under a different session after restart, logout, or workspace change.
- Encrypt sensitive queued data and add visible queue state, retries, deduplication, and quarantine behavior.

## 5. Real SaaS subscription lifecycle

**Status: implemented for a controlled pilot.** Dated trial/active/overdue/grace,
cancelled and suspended states, invoices, payment history, expiry progression,
and server-side staff/cashier entitlements are present. A payment gateway and
customer-facing upgrade checkout still require provider selection/integration.

- Add subscription start/end dates and trial, active, overdue, grace-period, cancelled, and suspended states.
- Add invoices, payments, billing history, renewal reminders, and upgrade/downgrade flows.
- Enforce plan entitlements on the server.
- Manual invoicing may be used during a controlled pilot, but expiry and entitlements must still be enforced.

## 6. Production release and operations

**Status: partial.** Release builds no longer use debug signing; CI, HTTPS/CORS,
rate limiting, structured request logs, readiness checks, and backup/restore
runbooks are included. Real keys, hosting, monitoring/crash vendors, alerting,
and a completed restore drill remain deployment work.

- Configure real Android release signing and remove debug signing from release builds.
- Complete product metadata, environment separation, HTTPS-only production configuration, and reproducible database bootstrap migrations.
- Add CI/CD, backend tests, end-to-end Flutter tests, structured logging, crash reporting, uptime monitoring, backups, and restore testing.

## 7. Legal, privacy, and customer support readiness

**Status: backend foundation implemented.** Versioned legal consent, retention
configuration, tenant-scoped support cases, and audited account-deletion
requests are modeled. Replace placeholder legal URLs, publish reviewed policy
text, add the customer-facing forms, and validate retention rules with counsel.

- Add privacy and terms acceptance with versioned consent records.
- Define receipt-image and financial-record retention/deletion rules.
- Add customer support, incident escalation, and account-deletion workflows.
- Document data handling and complete a production security/privacy review before general launch.

## Recommended implementation order

1. Atomic server verification and ticket creation.
2. Complete schema, RLS, authentication, and authorization.
3. Correct immutable ledger, tip payouts, and reporting.
4. Safe offline synchronization.
5. Subscription lifecycle and server-side entitlements.
6. Signed production builds, CI, monitoring, and backups.
7. Privacy, legal, support, retention, deletion, and scalable onboarding.
