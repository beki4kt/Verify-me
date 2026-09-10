# CHEKMI 1.0 release status — 10 September 2026

| Blocker | Implemented release state | Remaining external action |
|---|---|---|
| Production routes | Public verification uses the live Supabase `chekmi-verify` function. Alet and owner-console routes are absent from the store UI. | Apply the release environment in each store build. |
| Provider acceptance | The public binary and API client allow Telebirr only. Pilot builds retain the other providers. | Run a final fresh Telebirr receipt before submission. |
| iOS | CHEKMI icons, launch screen, bundle ID, privacy manifest, Xcode 26 workflow, and App Store upload path are present. | Add Apple certificate/profile/team/API secrets and run the workflow. |
| Android | CHEKMI package ID, API 36 target, Java 17 build, adaptive icons, private upload key, and signed AAB are present. | Back up `Documents\Chekmi-Secrets` and upload the AAB to Play Console. |
| Legal URLs | Full privacy, terms, support, and deletion pages plus Pages deployment are present. | Publish Pages and confirm the support/privacy mailboxes receive messages. |
| Account deletion | Any staff user can immediately anonymize their profile and revoke access; administrators retain a separate business-closure request. | Apply migration `202609100001_publishability.sql` to production. |
| Billing | Version 1.0 is documented and enforced as organization-only B2B access with no public plan sales. | Use the review notes in `store-release.md`. |
| Operations | Sanitized client error events, ten-minute health checks, incident issues, encrypted daily backups, and an ephemeral restore rehearsal are configured. | Add repository secrets and record the first successful scheduled runs. |
| Source state | Work is isolated on `release/publishable-20260910`; visual evidence and local secrets are ignored. | Merge the reviewed release commit to `main`. |

The signed Android release bundle is `build/app/outputs/bundle/release/app-release.aab`. Its SHA-256 is `1900F439ACB9253D8172FBB063CB398C7099C198F57FA9B995A226D96CB417C8`.

## Release order

1. Push and review `release/publishable-20260910`.
2. Enable GitHub Pages with GitHub Actions and verify all four public URLs.
3. Add Supabase deployment and backup secrets; apply the production migration.
4. Provision private reviewer roles in a dedicated workspace.
5. Run CI, health, backup/restore, Android release, and iOS App Store workflows.
6. Perform one fresh Telebirr verification and confirm the immutable ticket.
7. Submit the binaries with the metadata and review notes in `store-release.md`.
