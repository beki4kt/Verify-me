# CHEKMI functionality and response-speed audit — 18 September 2026

## Scope and evidence

This audit covers the customer-facing production path: workspace connection,
staff login, waiter verification and wallet, cashier settlement, tenant admin,
support, legal consent, and account deletion. Demo, pricing, and owner-console
controls are excluded from the production binary, but their existing automated
tests and the protected backend tests were still run.

- `flutter analyze --no-pub`: clean.
- Flutter tests: 70 passed; one iPhone-only suite is skipped by the normal
  Android build flag.
- iPhone layout suite with `CHEKMI_IPHONE_UI=true`: 8 passed.
- Backend verification/security tests: 52 passed.
- Production Android APK: compiled, package `com.chekmi.app`, version
  `1.0.0+1`, target API 36, zip-aligned, and verified with APK Signature v2.
- Production health: verifier, legal versions, required publishability RPCs,
  and four public legal/support pages passed.
- Production RPC compatibility: all 25 customer RPCs used by the app are
  deployed with the expected parameter names. Safe invalid sessions were used
  for mutation endpoints, so the audit changed no customer data.
- No physical Android or iOS device was connected. Camera/OCR, permission
  prompts, vibration, external-link launching, and successful authenticated
  mutations still require device testing.

## Control and function review

| Surface | Controls reviewed | Result |
|---|---|---|
| Workspace | Business code, keyboard submit, connect, theme, language | Correct validation, disabled/loading state, error state, and replacement navigation. |
| Staff login | Phone prefix, phone/password fields, password visibility, login, workspace change | Correct duplicate-submit prevention and role routing. Admin staff management was fixed to support the same `+2517` and `+2519` prefixes as login. |
| Waiter | Tabs, refresh, sign-out, help, bank picker, camera retry/change, capture, manual reference, verify, filters, history, tip visibility, withdrawal | Payment verification is server-authoritative and has timeout/status recovery. Paid withdrawals are now deducted from the displayed available balance. Camera and real-receipt behavior remains a physical-device check. |
| Cashier | Pending/settled tabs, ticket opening, settle, reject, refresh, help, sign-out | Buttons prevent repeated submission and the server controls immutable amount and state transitions. Successful settle/reject still needs an authenticated reviewer account. |
| Admin | Ledger filters, date range, receipt evidence, payment accounts, team add/edit/status, withdrawals, password, support/account controls | Staff passwords are now hidden with a visibility toggle and validated at eight characters. Staff forms support both mobile prefixes. Saving an empty payment-account configuration is blocked. Irreversible withdrawal actions still need explicit confirmation. |
| Support/legal | Case form, priority/category, refresh/retry, policy acceptance, external documents | Validation and errors are present. Async lifecycle guards were added. Existing consent state is not loaded when the screen reopens. Support cases expose status but no threaded owner response. |
| Account | Staff deletion, admin business closure | Reason validation, acknowledgment, confirmation, loading state, and error handling are present. The live migration exposes both required RPCs. A successful disposable-account test is still required. |

## Production response measurements

Seven sequential requests were made from the audit environment in Nairobi.
These numbers include local ISP, DNS, TLS, Supabase region/cold-start, and
GitHub Pages effects; they are a release signal rather than a global benchmark.

| Safe request | Median | Slowest / p95 |
|---|---:|---:|
| Verifier readiness | 1.863 s | 5.744 s |
| Current legal documents | 1.682 s | 3.062 s |
| Invalid workspace lookup | 1.720 s | 3.689 s |
| Account-deletion authentication gate | 1.632 s | 1.705 s |
| Privacy page | 0.869 s | 11.000 s |

Database calls are usable but not instant. The verifier and GitHub Pages both
showed cold or network outliers. The payment verification client allows 60
seconds for the provider and then performs a 12-second read-only recovery check.
That protects correctness, but the UI should explain progress after the first
two seconds instead of showing one undifferentiated spinner.

Dashboard polling is aggressive: ordinary data polls every five seconds and
withdrawals every three seconds. One waiter screen can generate roughly 32
requests per minute; an admin screen can generate roughly 44. The shared-stream
implementation prevents duplicate listeners for the same source, but polling
continues while the route remains mounted. This will affect battery, mobile data,
and Supabase load as usage grows.

## Defects corrected in this audit

1. Paid tip withdrawals could reappear as withdrawable in the waiter UI. The
   server already rejected a duplicate request; the screen now matches the
   server ledger and regression tests cover paid and overdrawn balances.
2. Admin staff creation/editing forced `+2519` even though login supports
   `+2517`. Both prefixes now round-trip correctly and are tested.
3. New staff passwords were displayed as plain text and only checked for being
   nonempty. They are now obscured, revealable, and checked against the server's
   eight-character minimum.
4. Admins could save no enabled payment account, leaving receipt verification
   unusable. The form now requires at least one account.
5. Support submission, external legal links, and deletion completion had async
   lifecycle/error gaps. They now avoid updating disposed screens and convert
   link-launch failures into an actionable message.
6. Five icon-only close/back controls lacked tooltips; accessible labels were
   added.

## Recommended release additions

### Required before store submission

1. Run one authenticated script or integration test for each role in a
   disposable production workspace: login, legal acceptance, support case,
   staff create/edit/pause, receipt verification, cashier settlement/rejection,
   tip withdrawal lifecycle, and staff deletion.
2. Test the Android build on a physical low/mid-range phone with camera denied,
   camera allowed, weak network, app background/resume, screen rotation, large
   text, and a fresh real Telebirr receipt.
3. Add request IDs/idempotency to support-case and admin mutation RPCs, then add
   a bounded timeout with a clear “status uncertain—refresh before retrying”
   state. Verification already has this safety model; the remaining writes do
   not.
4. Add confirmation dialogs for withdrawal approve, reject, and especially
   “mark paid.” Those transitions are financial and cannot be reversed in the
   current database workflow.
5. Complete and record the first encrypted backup/restore rehearsal.

### Highest-value product improvements

1. Replace the verification spinner with three short stages: checking provider,
   confirming destination/amount, and saving ticket. Show a “taking longer than
   usual” message after two seconds without adding a cancel action that could
   create an uncertain payment state.
2. Add a compact verification evidence card before cashier settlement showing
   provider, reference, verified amount, receiver suffix, provider time, and
   duplicate/recovered status. This directly supports CHEKMI's goal of making
   payment decisions trustworthy at a glance.
3. Add a visible refresh state and “updated N seconds ago” to dashboards. The
   current refresh buttons wake polling but give no immediate acknowledgment.
4. Move dashboards to Supabase Realtime or foreground-aware adaptive polling:
   fast while a queue is active, 10–15 seconds while idle, paused in background.
5. Load legal consent status from the server so accepted policies remain visibly
   accepted after reopening the screen.
6. Add support replies, not only case status, or change the success copy so it
   does not imply an in-app response that users cannot read.
7. Add an admin audit view and CSV export for settlements, rejected payments,
   tip payouts, and staff changes. This is more valuable for the final product
   than adding more dashboard decoration.

## Release assessment

The codebase is statically clean, automated verification/security coverage is
strong, all customer RPCs are deployed, and the identified deterministic UI
defects are fixed. A signed audited APK was built from these fixes. Store
readiness still depends on physical Android testing and the authenticated
production role matrix.
