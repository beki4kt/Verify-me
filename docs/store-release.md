# CHEKMI store release record

## Product and billing

Version 1.0 is an organization-only business client. Restaurants contract with
CHEKMI outside the mobile app and provide workspace access to their staff. The
public production binary does not create consumer accounts, advertise plans,
sell subscriptions, or unlock digital features through an external purchase.

Category: Business. Audience: authorized restaurant staff aged 18 or older.
Production package identifiers are `com.chekmi.app` on Android and iOS.

## Store listing

**Name:** CHEKMI

**Subtitle / short description:** Verify restaurant payments with confidence.

**Description:**

CHEKMI gives authorized restaurant teams one secure workspace for payment
verification and settlement operations. Connect the device with your business
code, sign in with your assigned staff account, verify supported payment
references, and keep waiter, cashier, and administrator work in sync.

- Verify supported transactions against provider evidence
- Prevent duplicate payment references
- Route verified tickets through settlement
- Keep role-based staff access and an auditable activity history
- Request support and control your account from inside the app

CHEKMI requires an active organization workspace. Version 1.0 supports
Telebirr verification.

**Keywords:** restaurant,payment,verification,telebirr,settlement,staff

**Support URL:** https://beki4kt.github.io/Verify-me/support.html

**Privacy URL:** https://beki4kt.github.io/Verify-me/privacy.html

**Terms URL:** https://beki4kt.github.io/Verify-me/terms.html

**Account deletion URL:**
https://beki4kt.github.io/Verify-me/delete-account.html

## App review notes

CHEKMI is licensed to organizations. There are no consumer purchases or account
creation in the app. A reviewer needs a production review workspace and staff
credentials supplied privately in App Store Connect and Play Console. The
review account must expose waiter, cashier, and administrator workflows or the
submission must include one account for each role. Keep the review workspace
active for the entire review period and provide a fresh Telebirr test reference
through the private review notes.

Camera access is optional. It extracts a transaction reference from a receipt;
manual reference entry remains available. Receipt and payment information must
never be placed in public review notes.

## Google Play Data safety answers

Declare the following data used for app functionality, fraud prevention,
security, support, and account management:

- Personal information: staff name and work phone number
- Financial information: payment provider, transaction reference, and amount
- Photos: receipt image when a user chooses camera scanning
- App activity: verification, settlement, support, and security audit events
- App information and performance: sanitized crash type, platform, and time

Data is encrypted in transit. Workspace data is tenant-scoped. Personal staff
accounts can be deleted in the app, and deletion can also be requested at the
public deletion URL. Financial audit rows may retain an anonymous staff
reference under the published retention policy.

## Submission evidence

Attach the signed Android App Bundle, the signed iOS IPA produced with Xcode 26,
phone screenshots without customer data, the live policy URLs, review account
instructions, the latest successful CI run, and the latest successful database
backup/restore-rehearsal run.
