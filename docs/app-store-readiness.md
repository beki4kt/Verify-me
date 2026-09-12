# Chekmi iPhone and App Store readiness

Last reviewed: 2026-09-10

This is an engineering checklist, not a guarantee of acceptance. Apple reviews
the complete binary, business model, metadata, backend availability, privacy
practice, and reviewer experience together.

## Current implementation

- Native Flutter iOS runner under `ios/`, targeting iPhone with a provisional
  bundle identifier of `com.chekmi.app` and a minimum deployment target of iOS
  15.5.
- iPhone presentation selected automatically on iOS. A Windows/web review can
  force it with `--dart-define=CHEKMI_IPHONE_UI=true`. Deterministic visual
  captures can additionally set `--dart-define=CHEKMI_UI_PREVIEW=true` to skip
  device storage; this flag must not be used for functional release testing.
- Cupertino entry experience with system typography, grouped surfaces, native
  navigation, native controls, Dynamic Type-compatible text, semantic labels,
  and iOS page transitions.
- Camera purpose text in `Info.plist`; Chekmi requests camera access only when a
  waiter starts receipt capture, and both camera controllers disable audio.
- App privacy manifest bundled in the Runner target. It declares no tracking
  and documents Chekmi's linked operational data: staff identity and phone,
  user ID, restaurant purchase history, submitted receipt images, and support
  requests. Third-party SDK declarations must be checked in Xcode's aggregated
  privacy report before release.
- `ITSAppUsesNonExemptEncryption` is currently `false`, on the assumption that
  Chekmi only uses exempt standard transport encryption such as HTTPS. Recheck
  this answer when the final binary and cryptography use are known.

## Mandatory release baseline

- Build and upload with Xcode 26 or later using the iOS 26 SDK. Apple has
  required this for App Store Connect uploads since April 28, 2026.
- Use an active Apple Developer Program organization account, register the
  final bundle ID, configure signing, and create the App Store Connect record.
- Archive on macOS, validate on physical iPhones, distribute an internal
  TestFlight build, and then submit the selected build for review.
- Complete required metadata: app name, subtitle, description, category, age
  rating questionnaire, support URL, privacy policy URL, pricing/availability,
  content rights, and export-compliance answers.
- Provide one to ten screenshots. A highest-resolution 6.9-inch iPhone set can
  scale down when the interface is the same across supported sizes and locales.
- Keep the review backend live. Supply a dedicated production review workspace,
  valid admin, cashier, and waiter credentials, a fresh Telebirr reference, and
  concise steps in App Review Information. The reviewer must be able to reach
  every important feature.

## Resolved release decisions

### Organization access and billing

Version 1.0 is organization-only. Restaurants contract with CHEKMI outside the
app, and the app signs existing restaurant staff into an active workspace. The
production binary hides pricing, plan requests, trial entry, and consumer
purchase calls to action. The review notes in `store-release.md` document this
model.

### Privacy policy and deletion

- Publish the prepared Privacy Policy, Terms, Support, and Account Deletion pages
  through GitHub Pages and verify their stable HTTPS URLs before submission.
- Any signed-in staff user can delete their personal account in the app. The
  production migration immediately anonymizes personal fields, disables the
  staff record, destroys its password material, revokes its sessions, and writes
  an audit record. Administrators retain a separate reviewed business-closure
  request for organization data and legally retained financial audit records.
- Reconcile `PrivacyInfo.xcprivacy`, App Store privacy answers, backend behavior,
  public policy, retention rules, logs, and every integrated SDK before upload.

## Final Mac/Xcode audit

- Confirm the generated CHEKMI AppIcon set and launch mark in the archived build;
  the 1024-pixel marketing icon is RGB with no transparency.
- Confirm the final bundle identifier and Apple development team in Xcode.
- Resolve Swift Package Manager dependencies and inspect every plugin's privacy
  manifest/signature. Generate Xcode's privacy report from the Release archive.
- Verify camera denial/recovery, receipt capture, background/foreground changes,
  offline storage, deep navigation, keyboard avoidance, reduced motion, VoiceOver,
  Larger Text, dark/light appearance, and all supported iPhone screen sizes.
- Confirm there is no placeholder copy, broken URL, hidden owner-only shortcut
  that confuses review, or feature dependent on an unavailable local service.
- Run release-mode tests against the exact staging backend used by App Review,
  then create and test the IPA through TestFlight.

## Apple sources

- Upcoming SDK requirements: https://developer.apple.com/news/upcoming-requirements/
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- App Review information and demo access: https://developer.apple.com/app-store/review/
- Privacy manifests: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Required-reason APIs: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- App privacy disclosures: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Account deletion: https://developer.apple.com/support/offering-account-deletion-in-your-app/
- Required metadata: https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties
- Screenshots: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- Export compliance: https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance
- Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines
- Flutter iOS release guide: https://docs.flutter.dev/deployment/ios
- Flutter platform adaptations: https://docs.flutter.dev/ui/adaptive-responsive/platform-adaptations
