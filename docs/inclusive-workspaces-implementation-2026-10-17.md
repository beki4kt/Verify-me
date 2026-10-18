# Inclusive workspaces: implementation and rollout audit

17 October 2026

The canonical product requirements are in `inclusive-workspaces-plan-2026-10-16.md`.

## Architecture audit

- Flutter owns the entry, staff login, scanner, review queue, and existing iPhone presentation. It calls Supabase RPCs with an opaque staff session and uses the `chekmi-verify` Edge function for authoritative receipt verification.
- PostgreSQL owns tenant isolation, receiving-account lookup, immutable provider evidence, duplicate prevention, ticket state, and the financial event ledger. The Edge and compatibility Express routes call the same `commit_verified_payment` RPC.
- Before this change, database and Edge permissions assumed waiter/admin verification and cashier/admin completion. The verification RPC treated every excess amount as a tip, and the Flutter login selected a dashboard by literal role.
- Existing restaurant records use `tickets.waiter_id` and `tickets.table_number`; these columns remain intact. No historical evidence or payouts are rewritten.

## Implemented

1. Additive `workspace_profiles` and tenant-scoped `workspace_member_capabilities`. Existing tenants are backfilled as restaurants with their review and tip policy. Newly provisioned tenants get generic references, automatic completion, and unresolved overpayments. Presets create initial grants; a use-case label is never evaluated as a runtime security role.
2. Capability checks now guard verification context, atomic commit, duplicate recovery, failed-attempt logging, review transitions, ledgers, receiving accounts, member administration, and workspace settings. The first admin keeps the owner preset. Member managers cannot modify owner accounts through the new controls.
3. Atomic commit now records `reference_kind`, `reference_value`, `verified_by`, and `unresolved_excess`. Automatic completion writes a separate `settled` financial event with actor and time. Review-required workspaces retain a pending ticket. Historical financial evidence remains immutable.
4. New excess defaults to unresolved, with no inferred staff tip. Optional explicit tip allocation creates an immutable allocation record, records the actor and reason, and updates the ticket projection. Allocations cannot exceed excess, target another member, or apply to refunded/voided/disputed payments. Existing restaurant tip history remains readable and withdrawable.
5. Both Edge and compatibility Express responses now use the database's tip allocation decision. The Edge function accepts capability-authorized cashier sessions and generates a neutral payment reference when none was entered. Status recovery still reads the original committed payment without repeating a provider lookup.
   The checked-in Supabase Edge bundle has been regenerated, and CI now fails if it is stale relative to TypeScript source.
6. Flutter has a shared capability-driven home for non-restaurant workspaces, settings, receiving-account editor, member permission controls, generic review copy, typed references including booking/note/none, configured receiving-account display before verification, and distinct verified/review/complete/excess result copy. Restaurants keep their familiar screens.
7. iPhone and web entry now present team connection, a gated personal path, and a guided sample preview. The guided preview is explicitly illustrative and can run without the live demo service. The live demo disables checks and offers the guide when its endpoint is unavailable. Personal self-registration remains closed until identity, recovery, abuse controls, and deletion are implemented.

## Validation performed

- Flutter analyzer: clean.
- Flutter unit/widget suite: 83 passed, 2 environment-gated tests skipped. Affected model, money, context, demo, and iPhone UI tests also pass after their final changes.
- iPhone layout suite: eight dark/light 390×844 cases pass.
- Backend TypeScript build and 55 tests pass, including cashier capability, duplicate recovery, destination checks, and overpayment response semantics.
- Release web preview compiles successfully.

## Rollout checklist and remaining work

1. Apply `supabase/migrations/202610160001_inclusive_workspaces.sql` to a staging PostgreSQL project and execute tenant-isolation, role/capability, duplicate, tip allocation, and legacy restaurant migration scenarios. This machine has no local PostgreSQL/Supabase CLI, so the migration has **not** been executed here.
2. Deploy the migration before the matching Edge and compatibility backend code, then release the Flutter client. Keep generic workspaces disabled in production until the server and client are both deployed and real receipts are exercised. The client falls back to the legacy restaurant route if the profile RPC is absent.
3. Restore and configure the separately deployed `chekmi-demo` function and its owned relay; verify readiness, quota, duplicate handling, and a real demo lookup. The guided preview does not pretend to perform a live check.
4. Run physical-iPhone acceptance for personal-preview, one-person admin, cashier-only, team review, restaurant, service reference, camera/manual input, offline/timeout recovery, accessibility, and English/Amharic copy. An iOS IPA cannot be built on this Windows host.
5. Finish self-service personal identity, recovery, abuse protection, account deletion, and plan/seat changes before advertising live personal signup. Keep the gated entry until these are complete.

This branch is an implementation candidate, not a production deployment or a publishability sign-off.
