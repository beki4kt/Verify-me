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
   configure the verifier service values plus `SUPABASE_URL` and the backend-only
   `SUPABASE_SERVICE_ROLE_KEY`. Never put the service-role key in Flutter.
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
   `202608120005_privacy_support_compliance.sql`.
5. Start the API with `npm run dev` in `backend-server`.
6. Start Flutter with the API address reachable by the device:
   `flutter run --dart-define=VERIFY_ME_API_URL=http://YOUR_PC_IP:3000/api`.

## Buyer trial mode

From the first screen, select **Try the live demo**. The trial runs entirely
offline with representative waiter, cashier, and admin data. It does not need a
workspace code, staff credentials, Supabase migrations, or a live payment.
Users can also switch between English and Amharic and preview both light and
dark glass themes from inside the tour.

The migration is designed to repair the schema lost during the collaborator
merge. It adds secure password hashing, expiring staff sessions, business plan
fields, ticket settlement fields, and duplicate transaction protection.
The second migration removes direct anonymous ticket access and requires the
short-lived staff session token for tenant-scoped reads and role-checked writes.

## Demo restaurant

After applying the migration, provision the app with business code `MESOB-DEMO`.
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
- Backend: `npx tsc --noEmit` and `npm test`

## Production builds

Web:

```powershell
flutter build web --no-pub
python -m http.server 8080 --directory build/web
```

Open `http://localhost:8080`. Camera/OCR remains a mobile-only workflow; use
the web build for provisioning, trial mode, dashboards, and API integration.

Android APK:

```powershell
flutter build apk --release --no-pub `
  --dart-define=VERIFY_ME_API_URL=https://YOUR-HTTPS-API/api
```

For phone development on the same Wi-Fi, replace the API address with the
computer's current LAN IPv4 address and use `flutter run` instead.
