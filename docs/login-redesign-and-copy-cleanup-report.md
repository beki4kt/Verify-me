# Login redesign and app-wide copy cleanup — verification report

Date: 2026-09-09

## Summary

The connected-business login panel and the app-wide concise-copy pass were
already present in the working tree. This pass verified every acceptance
criterion against the default build (`CHEKMI_MINIMAL_UI` defaults to `true`),
applied outstanding `dart format` cleanup, regenerated the login and demo
screenshots, and re-ran static analysis and the full test suite.

## Acceptance criteria

1. **Nothing appears above the business code inside the login panel.**
   Verified in `lib/core/widgets/staff_login_experience.dart`. Inside the
   gradient login box (`_form`), the first child is the
   `Key('login-business-code')` pill. No workspace status, team label,
   marketing text, badge, feature chip, or introductory explanation precedes
   it. The screen-chrome row above the box (brand lockup + language/theme
   toggles + back-to-workspace control) is intentionally retained as
   essential actions and is outside the login panel itself, consistent with
   the design note in `docs/demo-and-login-20260908.md`.

2. **The login panel clearly stands out as the page's premium focal point.**
   The panel uses a layered cyan→violet animated gradient border, an elevated
   shadow with a restrained primary glow, a subtle inner white border, hover
   lift via `MotorScale`, focus-driven field borders/icons, and a 56pt
   `FilledButton` with elevation + shadow on interaction. Works in dark and
   light themes and at the 390×844 phone layout.

3. **Redundant explanatory copy is removed throughout the app.**
   `AppVariant.usesMinimalCopy` (default `true`) gates concise copy across
   gateways, dashboards, payment flows, demo scanner, receipt/pricing
   screens, empty states, and navigation. Removed/shortened copy includes:
   `WORKSPACE CONNECTED`, `Your team. Ready for business.`, `Welcome back`,
   `EXPLORE LIVE DEMO` → `DEMO`, `CONNECT YOUR WORKSPACE` → `CONNECT`,
   `AMOUNT DUE` → `DUE`, long shortfall explanations → `AMOUNT BELOW DUE`,
   `Unbind Terminal?` → `Change workspace?`, and the verbose
   `Turn every transfer into a trusted…` hero subtitle (hidden in minimal
   mode). Demo scanner uses `10 free checks left` / `N free checks left`.

4. **Authentication and payment behavior remain unchanged.**
   No changes to `StaffLoginScreen._handleLogin`, validation, routing,
   business-code handling, `ApiService`, payment verification, or trial quota
   logic. Only formatting was applied to `pricing_screen.dart` and
   `receipt_parser.dart`; behavior is byte-for-byte equivalent.

5. **Tests and static analysis pass.**
   - `flutter analyze` → `No issues found!`
   - `dart format --set-exit-if-changed lib test` → 0 changed
   - `flutter test` → 64/64 passed

## Files changed in this pass

Formatting only (no behavioral change):

- `lib/pricing_screen.dart`
- `lib/receipt_parser.dart`
- `test/motion_widgets_test.dart`

## Essential explanatory text intentionally retained

- Operational errors and validation messages (e.g. `Enter your phone number
  and password.`, `Please enter exactly 8 digits.`, `Invalid credentials or
  inactive account.`, `This workspace connection expired. Choose the
  workspace again.`).
- Payment-safety/legal text on the support/privacy screen (account-closure
  reasons, suspension policy, plan-usage control language).
- Confirmation dialogs (`Change workspace?` / `Remove this workspace?`).
- Accessibility tooltips (`Show password` / `Hide password`, `Change
  workspace`, `Open demo scanner`, `Phone prefix`).
- The demo result disclaimer that the lookup is a demo and not a recorded
  business payment.
- Short action labels: `Sign in`, `Workspace`, `Demo`, `Payment method`,
  `DUE`, `10 free checks left`.

## Regenerated screenshots

Produced via `scripts/smoke_iphone_preview.mjs` and
`scripts/smoke_iphone_flow.mjs` against the running 390×844 web preview
(zero console errors/exceptions):

- `artifacts/preview-staff-login.png` — connected-business login panel
- `artifacts/preview-gateway-light.png` / `preview-gateway-dark.png` /
  `preview-gateway-amharic-dark.png` — gateway
- `artifacts/flow-gateway-light.png` / `flow-gateway-scrolled.png` /
  `flow-after-demo-tap.png` / `flow-trial-tap-*.png` — demo/trial flow

## Test results

```
flutter analyze      → No issues found!
dart format check    → 70 files, 0 changed
flutter test         → All tests passed! (64 tests)
```
