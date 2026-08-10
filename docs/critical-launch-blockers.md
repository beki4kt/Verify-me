# CHEKMI Critical Launch Blockers

These items were identified during the August 10, 2026 product-readiness audit.
They are intentionally deferred while the UI refresh is in progress.

## 1. Server-authoritative payment verification

- Replace the client-controlled verify/check/create sequence with one authenticated, atomic server operation.
- Validate the staff session, role, tenant, amount, destination account, provider result, and duplicate reference on the server.
- Match the receiving account for every supported provider, not only Telebirr and CBE.
- Create the immutable verification evidence, audit entry, and ticket in the same transaction.

## 2. Authentication and authorization hardening

- Remove the hard-coded `MASTER99` super-admin path.
- Replace the client-side super-admin password lookup with hashed server-side authentication, MFA, and audit logging.
- Add login rate limiting, temporary lockout, password recovery/reset, session-expiry UX, and device/session management.
- Move tenant, staff, payment-account, and subscription mutations behind role-protected RPCs or backend endpoints.
- Replace the optional global verifier API key with staff/tenant-aware server authentication.

## 3. Accurate and immutable financial records

- Store expected amount, verified amount, original tip, provider timestamp, payer/receiver data, and verification evidence.
- Record the actor, timestamp, and reason for every settlement, rejection, void, refund, or dispute.
- Prevent the cashier from replacing verified bank data with an unrelated manually entered amount.
- Add a proper waiter tip-payout ledger with pending, approved, and paid states.
- Replace last-100-ticket dashboard math with server-side date-range reports and accurate totals.

## 4. Safe offline synchronization

- Bind every queued record to its original tenant, staff member, and verification evidence.
- Prevent a queued ticket from syncing under a different session after restart, logout, or workspace change.
- Encrypt sensitive queued data and add visible queue state, retries, deduplication, and quarantine behavior.

## 5. Real SaaS subscription lifecycle

- Add subscription start/end dates and trial, active, overdue, grace-period, cancelled, and suspended states.
- Add invoices, payments, billing history, renewal reminders, and upgrade/downgrade flows.
- Enforce plan entitlements on the server.
- Manual invoicing may be used during a controlled pilot, but expiry and entitlements must still be enforced.

## 6. Production release and operations

- Configure real Android release signing and remove debug signing from release builds.
- Complete product metadata, environment separation, HTTPS-only production configuration, and reproducible database bootstrap migrations.
- Add CI/CD, backend tests, end-to-end Flutter tests, structured logging, crash reporting, uptime monitoring, backups, and restore testing.
- Add privacy, terms, support, retention, and account-deletion workflows before a general public launch.

## Recommended implementation order

1. Atomic server verification and ticket creation.
2. Complete schema, RLS, authentication, and authorization.
3. Correct immutable ledger, tip payouts, and reporting.
4. Safe offline synchronization.
5. Signed production builds, CI, monitoring, and backups.
6. Subscription billing, support, compliance, and scalable onboarding.
