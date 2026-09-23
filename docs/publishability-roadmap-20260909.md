# CHEKMI publishability roadmap

Audited: 9 September 2026

## Audit result for the latest agent pass

No application behavior needs to be reverted.

- The pass changed `lib/pricing_screen.dart` and `lib/receipt_parser.dart`
  through `dart format` only. Both files are identical to the last verified
  iPhone branch when whitespace is ignored.
- `test/motion_widgets_test.dart` is test-only and was formatted. It cannot
  change production behavior.
- The new report under `docs/` is documentation only.
- Static analysis passes. All 64 Flutter tests, all 11 dedicated iPhone UI
  tests, all 52 backend tests, and TypeScript compilation pass.

The clean iPhone build branch remains at `f377b4b`. The main checkout contains
a large uncommitted development set, so publication must start by consolidating
that work into one reviewed release commit.

## Current release status

| Area | Status | Evidence and implication |
| --- | --- | --- |
| UI and automated tests | Ready for release hardening | Analyzer and all current Flutter/backend suites pass. |
| iPhone test package | Available for device testing | Build 7 is an ARM64 unsigned AltStore IPA. It is not an App Store-signed archive. |
| Payment verification service | Staging service healthy | The Supabase `chekmi-verify` function reports `ready`, live Veritas mode, version `2026-09-08.2`. |
| Production routing | Blocked | `config/production.json` omits `CHEKMI_VERIFICATION_URL`, so verification falls back to the configured Alet API. Its health, `/api/verify-and-create`, and `/api/operator/login` routes all return HTTP 404. |
| Live provider acceptance | Blocked | Telebirr has been confirmed on a real receipt. CBE, CBE Birr, Dashen, Abyssinia, and M-Pesa still require fresh-receipt tests with the correct receiving accounts. |
| iOS signing | Blocked | Bundle ID is `com.chekmi.app`, but no Apple development team or App Store signing pipeline is configured. |
| iOS branding | Blocked | The 1024px App Store icon is still Flutter's generated placeholder; the launch screen is also the generated Flutter launch image. |
| Android bundle | Blocked | The project targets API 36, but no production upload keystore exists. Local release builds also need Java 17 selected explicitly. |
| Android tooling | Maintenance required | Flutter 3.47 warns that AGP 8.11.1 and Kotlin 2.2.20 should move to at least AGP 9.0.1 and Kotlin 2.3.20. |
| Legal URLs | Blocked | Database bootstrap files still use `https://YOUR_DOMAIN/privacy` and `/terms`; the app itself says final public documents are outstanding. |
| Account deletion | Incomplete | A business admin can submit a reviewed deletion request. Staff-account deletion, final deletion execution, retained-data disclosure, and a public web deletion path are not proven. |
| Billing model | Decision required | Basic/Pro currently sends a manual billing request. Store billing treatment depends on whether CHEKMI launches as organization-only B2B software or public self-service SaaS. |
| Operations | Incomplete | Production monitoring, crash reporting, alerts, on-call ownership, and a completed backup/restore drill are not demonstrated. |

## Recommended launch model

Use an organization-only B2B launch for version 1.0. Restaurants purchase or
contract for CHEKMI outside the app, and authorized employees sign into an
existing workspace. For the store build:

- Remove public purchase and upgrade calls to action from the mobile app.
- Keep plan administration in the protected owner service or external business
  onboarding process.
- Explain the organization-only model and provide reviewer credentials in the
  review notes.

This is the shortest credible route because Apple permits enterprise users to
access organization-purchased subscriptions under guideline 3.1.3(c). If
CHEKMI will sell Basic or Pro to individuals or accept payment for app features
inside the app, implement StoreKit and Google Play Billing before submission.

## P0 - establish one releasable product

Complete these before external beta testing.

1. **Consolidate source control**
   - Review and commit the intended main working-tree changes.
   - Merge the verified iPhone UI branch into the release line.
   - Exclude screenshots, generated build output, local production config, and
     server secrets from source control.
   - Tag one release candidate and make CI build only from that commit.

2. **Repair production routing**
   - Set the production `CHEKMI_VERIFICATION_URL` to the deployed Supabase
     `chekmi-verify` function, or deploy a working equivalent route.
   - Deploy the protected owner/operator backend for provisioning,
     subscriptions, support, and deletion review; replace the dead Alet URL.
   - Add automated health and authenticated smoke checks for both services.
   - Keep Veritas and Supabase service-role keys server-side and rotate any key
     that has ever been placed in a client artifact or shared log.

3. **Prove the deployed database and authorization**
   - Apply the final migrations from a clean database and record the migration
     versions used in production.
   - Exercise tenant isolation, staff roles, RLS, session expiry/revocation,
     support cases, deletion requests, staff CRUD, settlements, disputes, and
     payout state transitions against staging.
   - Verify a user from one business cannot read or mutate another business.

4. **Close payment correctness decisions**
   - Decide whether an amount above the invoice is a waiter tip, overpayment,
     deposit, or exception; update the ledger and copy to match that decision.
   - Decide whether split payments are supported. If they are not, document and
     test the single-receipt rule.
   - Add durable database-level idempotency before provider lookup where
     practical so concurrent Edge workers do not spend duplicate credits.

## P1 - legal, privacy, and commercial readiness

1. Publish counsel-reviewed Privacy Policy, Terms of Service, and support pages
   at stable HTTPS URLs owned by CHEKMI. Replace every `YOUR_DOMAIN` value and
   link the documents from inside the app.
2. Implement complete account deletion:
   - clear in-app deletion for every account type that can be created;
   - a public web deletion request path for Google Play;
   - execution deadlines, status, cancellation rules, identity checks, and a
     precise explanation of financial records retained by law.
3. Reconcile the real data flow with `PrivacyInfo.xcprivacy`, Apple App Privacy,
   Google Data safety, Supabase, Veritas, logs, receipt images, support cases,
   crash reporting, and retention jobs.
4. Record rights or agreements for payment-provider names, logos, receipt
   access, and third-party verification services.
5. Finalize the organization-only sales model. If public self-service remains,
   replace the manual plan-request flow with compliant store billing and full
   subscription purchase/restore/cancel behavior.

## P2 - production builds and store records

### iOS

1. Enroll the owning legal entity in the Apple Developer Program, register the
   final `com.chekmi.app` identifier, set the development team, and configure
   App Store distribution signing.
2. Replace every Flutter placeholder icon and launch image with approved CHEKMI
   artwork. Confirm the 1024px marketing icon has no transparency.
3. Archive with Xcode 26 or later and the iOS 26 SDK, validate the archive, and
   inspect Xcode's aggregated privacy report and required-reason API results.
4. Upload to App Store Connect and run an internal TestFlight cycle before
   external review.
5. Complete name, subtitle, description, keywords, category, updated age-rating
   questionnaire, privacy answers, support/privacy URLs, export compliance,
   content rights, territory availability, and trader status where applicable.
6. Capture one to ten App Store screenshots from the full working product on a
   supported 6.9-inch iPhone size. Screenshots should demonstrate payment,
   dashboard, and operational flows rather than relying on the login screen.

### Android

1. Confirm ownership of the final application ID
   `com.leulverify.verify_me`; changing it after Play publication creates a new
   app identity.
2. Generate and securely back up a production upload keystore, configure Play
   App Signing, and build a signed `.aab` with Java 17.
3. Upgrade AGP and Kotlin after a clean compatibility run, then keep target API
   36 or later. API 36 is required for new apps and updates from 31 August 2026.
4. Replace generated launcher/splash assets with final adaptive CHEKMI assets.
5. Complete the Play store listing, content rating, ads declaration, app-access
   instructions, camera permission declaration, Data safety, privacy policy,
   and account-deletion URL.
6. Run internal and closed testing; satisfy any production-access testing rules
   that apply to the specific Play developer account.

## P3 - live acceptance and review package

1. Test all six payment providers using fresh real receipts and the configured
   receiving account for the pilot business. Record provider, receipt format,
   amount, expected destination proof, result, latency, and failure category.
2. Test physical iPhones and representative Android devices for camera
   permission grant/denial/recovery, OCR, background/resume, keyboard avoidance,
   offline and poor-network behavior, dark/light mode, Larger Text, VoiceOver or
   TalkBack, reduced motion, and every supported role.
3. Create an App Review tenant with active admin, cashier, and waiter accounts,
   seeded non-sensitive data, usable receipt references, and stable instructions.
   Keep the backend online throughout review.
4. Run security and privacy acceptance: dependency review, secret scan, session
   theft/revocation tests, tenant-boundary tests, abuse/rate-limit tests, log
   redaction review, and deletion/retention verification.
5. Resolve every crash, failed provider, inaccessible control, and P0/P1 finding
   before selecting the release build.

## P4 - operate the published service

1. Add production error and crash reporting with data redaction, uptime probes,
   latency/error dashboards, credit-usage alerts, and provider-specific alerts.
2. Assign incident response, customer support, privacy requests, billing, and
   store-review ownership with response targets.
3. Automate encrypted backups, complete a timed restore drill, document rollback
   for app, backend, Edge function, and database migrations, and retain evidence.
4. Release to a small controlled group first, monitor verification accuracy and
   support volume, then expand availability.

## Publishable definition of done

CHEKMI is ready to submit only when all of the following are true:

- One clean tagged commit produces reproducible signed App Store and Play builds.
- The exact production build uses healthy production endpoints and passes role,
  tenant, deletion, subscription, and payment smoke tests.
- All intended payment providers pass fresh-receipt acceptance, or unsupported
  providers are removed from the release.
- Privacy, Terms, support, retention, and deletion flows are public and match
  store disclosures and real backend behavior.
- The billing model satisfies the selected store distribution model.
- Final icons, screenshots, metadata, reviewer access, and compliance answers
  are complete.
- Monitoring, alerting, backup restore, rollback, and support ownership are live.

## Current official references

- Apple SDK requirements: https://developer.apple.com/news/upcoming-requirements/
- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Apple screenshot submission: https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/
- Google Play target API policy: https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-GB_ALL
- Google Play Data safety: https://support.google.com/googleplay/android-developer/answer/10787469?hl=en
- Google Play account deletion: https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN
- Google Play payments policy: https://support.google.com/googleplay/android-developer/answer/9858738?hl=en
