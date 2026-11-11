# Chekmi publication readiness — 15 October 2026

Chekmi has a functioning release design and a native iPhone build pipeline.
The unsigned iPhone test IPA from
[build 8](https://github.com/beki4kt/Verify-me/actions/runs/38722388085)
is available at `build/iphone-relay-20261015/Chekmi-iPhone.ipa` locally.
It is **not yet ready for App Store submission** because the owned verifier is
not deployed, live receipts have not passed acceptance, and Apple signing
assets are absent from the repository's Actions secrets. The public binary
currently limits verification to Telebirr; keep that scope until each other
method has been proven with fresh bank receipts.

## Required before submission

| Priority | Action and acceptance evidence |
| --- | --- |
| 1. Restore the backend | Deploy a reachable Chekmi API with `CHEKMI_VERIFICATION_ENGINE=owned`, `CHEKMI_PROVIDER_EGRESS=proxy`, Supabase service credentials, and the three private relay URL/key pairs. `/ready` must return HTTP 200 with `verifier.engine: owned` and `verifier.configured: true`. The former Alet URL returned 404 on 15 October. |
| 2. Switch the Edge functions | Set `CHEKMI_BACKEND_URL` and the matching `CHEKMI_INTERNAL_LOOKUP_KEY` in Supabase secrets, deploy both `chekmi-verify` and `chekmi-demo`, and confirm GET reports `engine: owned`, version `2026-10-15.1`. Update the production health monitor together with the deployment. Do not place keys in Flutter or Git. |
| 3. Accept real receipts | On a physical iPhone, use a fresh matching business receipt for each enabled method. Confirm the returned amount, destination, time, duplicate behavior, saved ticket, cashier settlement, and timeout recovery. Record bank and relay latency at p50 and p95 from structured server logs. Use this evidence before enabling CBE, M-Pesa, Dashen, Abyssinia, or CBE Birr in the public binary. |
| 4. Sign an App Store IPA | Add Apple distribution certificate, provisioning profile, team ID, and keychain secrets expected by `ios-app-store.yml`; validate bundle ID `com.chekmi.app`. The AltStore workflow produces an unsigned test IPA, which is not an App Store artifact. Build with Xcode 26 or later and the iOS 26 SDK, as [Apple requires for uploads since 28 April 2026](https://developer.apple.com/news/upcoming-requirements/?id=02032026a). |
| 5. Complete App Store Connect | Supply the correct build, description, category, age rating, support and privacy URLs, data-collection answers, export-compliance answers, and required device screenshots. Apple [requires a privacy policy and app-privacy disclosures](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/) and [at least one required iPhone screenshot](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications). |
| 6. Prepare App Review | Give Apple an active reviewer workspace, role-specific credentials, exact steps, and a safe fresh verification example in private review notes. The reviewer must be able to reach every feature included in the public build; [Apple asks for working demo access and complete review information](https://developer.apple.com/app-store/review/). Test staff deletion from the installed build and explain any legally retained financial records; [account deletion must be initiable in-app](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion/). |

## Quality and operations before general availability

- Test camera permission denial and recovery, on-device OCR, manual entry,
  background/foreground return, poor connectivity, and older supported iPhones.
  Check dark/light themes, English/Amharic text, accessibility labels, and
  larger text settings on a physical device.
- The privacy, terms, support, and deletion URLs each returned HTTP 200 on
  15 October 2026. Respond to an in-app support case, run a database backup
  and restore rehearsal, and confirm health alerts reach
  an operator. The health check has been changed to expect `engine: owned` in
  source, but the deployed service currently still reports Veritas.
- Keep Basic/Pro as an informational organization request until billing is
  operational. The current app does not charge or activate a plan itself.
  Apple's [enterprise-services rule](https://developer.apple.com/app-store/review/guidelines/uk/)
  can allow organization access to services purchased outside the app, but the
  public listing and review notes must accurately describe the actual purchase
  and access flow.
- Validate the final IPA on TestFlight with the same configuration intended
  for customers. [TestFlight supports beta distribution and feedback](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/);
  it does not replace real provider acceptance.

## Useful additions after the first publishable release

These expand the product but are not prerequisites for a Telebirr-only business
release: automated organization billing and plan activation, refund and split
payment workflows, bank reconciliation exports, push alerts for cashier queues,
more detailed operational dashboards, and wider provider coverage after live
acceptance. Each financial workflow should preserve the existing atomic commit,
tenant isolation, and immutable audit trail.
