# CHEKMI

Mobile-first restaurant payment verification for Ethiopian payment providers.
The CHEKMI Flutter app provisions a restaurant terminal, authenticates staff by role,
verifies transfers through the TypeScript API, and records waiter/cashier tickets.

## Supported providers

- Telebirr
- Commercial Bank of Ethiopia (CBE)
- CBE Birr
- Dashen Bank
- Bank of Abyssinia
- M-Pesa

## Local setup

1. Run `flutter pub get` in the repository root.
2. Run `npm install` inside `backend-server`.
3. Copy `backend-server/.env.example` to `backend-server/.env` when present and
   configure CHEKMI's owned provider route plus `SUPABASE_URL` and the
   backend-only `SUPABASE_SERVICE_ROLE_KEY`. Never put service or relay secrets
   in Flutter. See `docs/owned-verifier-deployment.md`.
4. Apply the Supabase migrations in filename order before testing staff login:
   `202608040001_restore_verifier.sql`, then
   `202608040002_secure_ticket_tenants.sql`, then
   `202608050001_waiter_wallet_history.sql`, then
   `202608050002_verification_attempts.sql`, then
   `202608090001_admin_password_change.sql`, then
   `202608110001_admin_filters_receipts_withdrawals.sql`, then
   `202608120001_atomic_server_verification.sql`, then
   `202608120002_auth_and_tenant_hardening.sql`, then
   `202608120003_immutable_financial_ledger.sql`, then
   `202608120004_subscription_lifecycle.sql`, then
   `202608120005_privacy_support_compliance.sql`, then
   `202608170001_payment_correctness.sql`, then
   `202608220001_operator_console.sql`.
   Known demo credentials are not created by production migrations. For a
   local or staging database, explicitly apply `supabase/seed.sql` afterward.
5. Create the protected owner credentials inside `backend-server` with
   `npm run operator:setup -- you@example.com`. Save the generated password in
   a password manager, add the setup key to an authenticator app, and paste only
   the four `OPERATOR_*` values into the server's `.env` file.
6. Start the API with `npm run dev` in `backend-server`.
7. Start Flutter with the API address reachable by the device:
   `flutter run --dart-define=CHEKMI_ENV=development --dart-define=VERIFY_ME_API_URL=http://YOUR_PC_IP:3000/api`.

## Owner control center

Tap the CHEKMI logo on either login screen to open the protected owner gate.
Sign in with the generated owner email and password plus the current six-digit
code from your authenticator. The session expires after two hours and stays in
memory only. Restaurant access, plans, sessions, support, privacy reviews, and
system health are managed through backend-only service-role operations and are
written to the operator audit log.

## Buyer trial mode

From the first screen, select **Try the live demo**. The waiter role enters the
same authenticated waiter dashboard and verification workflow as restaurant
staff; cashier and admin retain guided preview data. The live waiter path needs
the seeded demo workspace and a reachable CHEKMI backend. Users can switch
between English and Amharic and preview both light and dark themes.

## Pricing, support, and privacy

Pricing is presented as one animated Basic-or-Pro decision screen. Signed-in
restaurants can submit the selected plan and billing period directly to the
protected owner queue. Every staff dashboard also links to Help & Privacy for
tenant-scoped support cases and versioned legal consent; restaurant admins can
submit an audited account-deletion request for owner and retention review.

The migration is designed to repair the schema lost during the collaborator
merge. It adds secure password hashing, expiring staff sessions, business plan
fields, ticket settlement fields, and duplicate transaction protection.
The second migration removes direct anonymous ticket access and requires the
short-lived staff session token for tenant-scoped reads and role-checked writes.
Provider lookup parameters such as CBE account suffixes and CBE Birr receiving
phones are derived from the restaurant account configuration on the backend;
staff clients submit only the receipt reference and bill details.

## Demo restaurant

After applying the migrations and the explicit local/staging seed, provision
the app with business code `MESOB-DEMO`.
The phone field displays the `+2519` prefix, so enter only the final eight digits.

| Role | Phone field | Password |
| --- | --- | --- |
| Admin | `11000001` | `AdminTest!2026` |
| Cashier | `11000002` | `CashierTest!2026` |
| Waiter | `11000003` | `WaiterTest!2026` |

These accounts are for local testing only. Change or remove them before a
production deployment.

## Validation

- Flutter: `flutter analyze --no-pub` and `flutter test --no-pub`
- iPhone layout suite: `flutter test --dart-define=CHEKMI_IPHONE_UI=true test/iphone_layout_test.dart`
  (skips automatically during a plain `flutter test`, which stays green)
- Backend: `npx tsc --noEmit` and `npm test`
- Owned verifier deployment and acceptance: `docs/owned-verifier-deployment.md`
- iPhone and App Store readiness: `docs/app-store-readiness.md`
- Test on an iPhone without an App Store upload: `docs/iphone-device-testing.md`

## Motion and interaction design

The motion language lives in `lib/core/theme/app_motion.dart` and is shared by
both presentations:

- `Pressable` gives custom rows/cards a spring scale-press with a selection
  haptic (Motor physics), so non-Button widgets feel like the app's buttons.
- `FadeThroughSwitcher` swaps related content (scanner states, cashier tabs)
  with a fade-through so the outgoing surface leaves first.
- `FadeSlideIn` provides capped entrance stagger; `AppMotion.stagger` keeps
  lists readable without long delays.
- State views (`LoadingView`, `EmptyView`, `ErrorView`, `OfflineView`,
  `ErrorBanner`) are theme-aware and calm: empty states offer a doorway
  action, failures offer retry, and the error banner shakes once.
- Success feedback (`SuccessOverlay`) only ever follows the backend's
  authoritative verified/settled result; pending and failed results never
  render success motion. Amounts in its message are the backend's values.
- Perpetual loops (skeleton shimmer, breathing empty states) are gated by
  `AppMotion.loopingAnimationsAllowed`, so `pumpAndSettle` still settles under
  `flutter test` and reduced-motion users are respected everywhere.

## iPhone development

Chekmi automatically uses its Cupertino presentation on iOS. To review that
presentation on an iPhone from this Windows PC, first run the firewall helper
once in an Administrator PowerShell, then start the preview normally:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\allow_iphone_preview_firewall.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\start_iphone_preview.ps1
```

Open the local-network URL printed by the second command in iPhone Safari. See
`docs/iphone-device-testing.md` for functional staging mode and native Xcode
installation without TestFlight or an App Store upload. The default preview is
an optimized release runtime, is interactive, and initializes Hive. Add
`-Development` while actively coding when hot reload is more important than realistic
Safari performance. Use `-VisualOnly` only for deterministic
screenshots that do not exercise data-changing actions.

`CHEKMI_UI_PREVIEW` skips device-storage startup for deterministic visual
captures, so data-changing actions are not part of that preview. The browser
preview validates layout and shared Dart behavior, but it cannot
validate the camera permission prompt, iOS lifecycle, signing, StoreKit,
TestFlight, or an App Store archive. Those checks require macOS, Xcode 26 or
later, and an iPhone or iOS simulator.

## Repeatable staging bootstrap

1. Copy `config/staging.example.json` to `config/staging.json` and replace all
   placeholders with the staging HTTPS API and public Supabase values.
2. Install PostgreSQL command-line tools so `psql` is available.
3. Run the guarded bootstrap command with the exact database hostname shown in
   the staging connection string:

```powershell
.\scripts\bootstrap_staging.ps1 `
  -DatabaseUrl 'postgresql://USER:PASSWORD@STAGING_HOST:5432/postgres' `
  -ExpectedDatabaseHost 'STAGING_HOST'
```

The script applies migrations in filename order, adds only the explicitly
marked staging demo data, and runs `supabase/staging_verification.sql`. It stops
on the first SQL error and refuses a connection whose hostname does not match
the separately supplied staging hostname. Existing staging databases can use
`-SkipMigrations` to refresh the demo seed and rerun the assertions.

Run the web app against staging with:

```powershell
flutter run -d chrome --dart-define-from-file=config/staging.json
```

For deterministic browser testing, set these values only on the staging API:

```dotenv
NODE_ENV=production
CHEKMI_ENV=staging
CHEKMI_VERIFIER_MODE=fixtures
```

The app displays a permanent `STAGING` banner. Fixture references are
`CHEKMI-OK`, `CHEKMI-TIP`, `CHEKMI-UNDERPAID`, `CHEKMI-WRONG-DEST`,
`CHEKMI-STALE`, `CHEKMI-NOT-FOUND`, and `CHEKMI-OUTAGE`. Reusing a successful
reference exercises duplicate/idempotent recovery. The backend refuses to
start with fixture mode when `CHEKMI_ENV=production`.

## Production builds

Web:

```powershell
Copy-Item config/production.example.json config/production.json
# Replace every placeholder in config/production.json with the deployed public values.
flutter build web --release --no-pub `
  --dart-define-from-file=config/production.json
python -m http.server 8080 --directory build/web
```

Open `http://localhost:8080`. Camera/OCR remains mobile-only; the web build
provides manual receipt entry so provisioning, verification, settlement,
dashboards, trial mode, and API integration can be tested in a browser.

Android Play Store bundle:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\build_android_release.ps1
```

Production builds require the deployed Supabase URL, publishable key, and the
project's HTTPS `chekmi-verify` Edge Function URL. An additional CHEKMI API URL
is required only for builds that expose the protected operator service. Missing,
HTTP, bind-address, and placeholder values stop the app before local storage or
network access begins.
The Supabase service-role key remains backend-only and must never appear in this
file. Android release signing must also be configured through
`android/key.properties` using `android/key.properties.example` as the template.

Store metadata, policy URLs, review notes, and the final deployment order are in
`docs/store-release.md` and `docs/release-status-20260910.md`.

For phone development on the same Wi-Fi, replace the API address with the
computer's current LAN IPv4 address and use `flutter run` instead.
