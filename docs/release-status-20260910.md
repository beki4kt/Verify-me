# CHEKMI 1.0 release status — 12 September 2026

| Blocker | Implemented release state | Remaining external action |
|---|---|---|
| Production routes | Public verification uses the live Supabase `chekmi-verify` function. Alet and owner-console routes are absent from the store UI. | Apply the release environment in each store build. |
| Provider acceptance | The public binary and API client allow Telebirr only. Pilot builds retain the other providers. | Run a final fresh Telebirr receipt before submission. |
| iOS | CHEKMI icons, launch screen, bundle ID, privacy manifest, Xcode 26 workflow, and App Store upload path are present. | Add Apple certificate/profile/team/API secrets and run the workflow. |
| Android | CHEKMI package ID, API 36 target, Java 17 build, adaptive icons, private upload key, and signed AAB are present. GitHub run `34509914833` produced the signed artifact successfully. | Back up `Documents\Chekmi-Secrets` and upload the AAB to Play Console. |
| Legal URLs | Privacy, terms, support, and deletion pages are live, health-checked, and use the repository owner’s established public contact address. | Keep the support inbox monitored during review. |
| Account deletion | Migration `202609100001_publishability.sql` is live; the deletion RPC rejects an invalid session as expected. Staff can anonymize their profile and revoke access; administrators retain a separate business-closure request. | Test deletion end to end with a dedicated reviewer account on a physical device. |
| Billing | Version 1.0 is documented and enforced as organization-only B2B access with no public plan sales. | Use the review notes in `store-release.md`. |
| Operations | Sanitized client error events, ten-minute health checks, incident issues, encrypted daily backups, and an ephemeral restore rehearsal are configured. The health check now verifies the legal versions and both required RPCs. The backup passphrase has a protected recovery copy and is stored as an Actions secret. | Add `SUPABASE_DB_URL`, record the first successful backup/restore run, and test a real authenticated client error. |
| Source state | Pull request `#1` contains the reviewed release branch; CI run `34590749194` passed Flutter, backend, public-gate, and production web checks. Local secrets and visual evidence are ignored. | Merge the reviewed pull request to `main`. |

The signed Android release bundle is `build/app/outputs/bundle/release/app-release.aab`. Its SHA-256 is `1900F439ACB9253D8172FBB063CB398C7099C198F57FA9B995A226D96CB417C8`.

## Release order

1. Review and merge pull request `#1`.
2. Add the Supabase database URL secret and run the first backup/restore.
3. Provision private reviewer roles in a dedicated workspace.
4. Run the iOS App Store workflow after adding its signing and App Store Connect secrets.
5. Perform one fresh Telebirr verification and confirm the immutable ticket.
6. Submit the binaries with the metadata and review notes in `store-release.md`.
