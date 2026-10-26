# Chekmi plan: one payment verifier for every kind of workspace

16 October 2026

## Product decision

Keep one receipt-verification and audit engine. Let a workspace choose how people
use it: one person, one cashier, or a team with a review step. “Restaurant,”
“shop,” “service,” and “personal” are setup presets and vocabulary choices, not
separate apps or security roles. Every workspace can change its workflow later
without losing its receipts or being forced into a restaurant structure.

| Example | Setup default | Main experience | Optional features |
| --- | --- | --- | --- |
| Personal or solo trader | One owner, one receiving account, no approval queue | Scan or enter a receipt, verify it, see personal history | Invoice/order note, export |
| Shop with one cashier | One person can verify and finish a sale | Verify payment and mark the sale complete in one flow | Shift report, second staff member |
| Shop with several staff | Staff verify; manager or cashier reviews | Shared payment queue and ledger | Approval rule, staff management |
| Restaurant | Existing staff-and-cashier workflow | Table or order context and optional tips | Tip payouts, table labels |
| Service provider | Owner or staff verify against a job or invoice | Invoice, booking, or customer context | Team review, exports |

Do not make a user choose an industry before the first useful action. A short
setup asks who will use Chekmi (“Just me” or “My team”), whether payments need
another person's review, and which receiving account to verify. The industry
preset can preselect a reference label and optional features. Apple recommends
short onboarding with reasonable defaults and postponing nonessential setup:
[Human Interface Guidelines: Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding).

## What the current app already supports, and what is still hard-coded

- `PaymentContext` already supports invoice, order, customer, table, and a
  general note. The reference is optional in the UI, though the server stores
  a generated `Payment: <bank reference>` string in `tickets.table_number`.
- Staff login chooses a different dashboard from the literal database role:
  `waiter`, `cashier`, or `admin`. Verification is allowed for `waiter`/`admin`;
  settlement and the business ledger are allowed for `cashier`/`admin`.
  A cashier-only shop cannot verify under its own cashier login.
- Business provisioning is operator-led and asks for a restaurant name, code,
  and root administrator. A personal user cannot create a workspace in the app.
- `has_cashier_module` and staff limits are coupled to the subscription. The
  Basic catalog allows one staff seat; the Pro catalog includes the cashier
  workspace and tip payouts.
- The server classifies every verified amount above the expected amount as a
  tip. That is unsafe as a general rule for shops, personal payments, refunds,
  or customer overpayments.
- Tickets and receipt evidence use `waiter_id` and `table_number` names. Existing
  restaurant records and audit events must remain readable throughout migration.

## Target structure

1. Add a `workspace_profile` containing a non-security `use_case` preset,
   `default_reference_kind`, `review_policy`, `tips_enabled`, and
   `overpayment_policy`. Defaults are generic: payment reference, no tips, and
   a one-person flow. The owner can edit these settings later.
2. Separate **membership** from **permissions**. The first owner gets all
   workspace permissions. A member may hold one or more capabilities such as
   `verify_payment`, `review_payment`, `manage_receiving_accounts`,
   `manage_members`, `view_ledger`, and `manage_tips`. Role names shown in the
   UI are presets: Owner, Payment staff, Reviewer. A single cashier can have
   both verify and review. The server must enforce every permission in its RPCs
   and Edge functions; hiding a tab is not authorization. Preserve tenant
   isolation and service-only financial writes. Supabase documents row-level
   controls for multi-tenant authorization: [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).
3. Separate **bank verification** from **business completion**. The bank result
   remains immutable evidence. A workspace chooses `automatic` completion
   after successful verification or `review_required` completion by an
   authorized member. Record who completed it and when. Do not label an
   internal completion as another bank verification.
4. Replace the automatic `verified - expected = tip` rule. Default to a
   separately recorded, unresolved overpayment, with no staff tip or payout.
   Enable tips only for workspaces that opt in and require an explicit tip
   allocation. Keep the verified amount, expected amount, allocated tip, and
   remaining excess distinct in the immutable ledger. Existing tip history
   remains unchanged.
5. Add typed `reference_kind` and `reference_value` fields to payment records.
   Continue reading legacy `table_number` values and their typed prefixes.
   New screens show “Invoice,” “Order,” “Booking,” “Customer,” “Table,” or
   “Note” according to the workspace default, with “No extra reference” valid.
   Rename `waiter_id` to a neutral actor/member concept in application code;
   add a stable column or view before changing persisted schemas.
6. Model personal use as a one-member workspace using the same tenant,
   receiving-account, receipt, and audit rules. Add self-service registration,
   recovery, and workspace deletion only after their identity and abuse controls
   are designed. A personal workspace must not inherit operator-only powers.

## Frontend flow

- Entry: “Use Chekmi on my own,” “Connect to my team,” and “Explore a preview.”
  A connected user lands on the actions they can perform, rather than a
  dashboard selected from a restaurant job title.
- Home: one primary “Verify payment” action. Show “Review payments” only when
  review is enabled and the member has permission. Show account settings and
  ledger according to capability. A solo user sees Verify, Activity, and
  Settings; a reviewer sees a queue; restaurants may keep the present tabs.
- Receipt form: provider, scan/manual reference, amount due, optional context.
  Put the configured receiving account in view before submission. Use
  business-neutral success copy: “Payment verified” and, if relevant,
  “Marked complete.”
- Settings: a compact “How this workspace handles payments” screen controls
  review, context labels, receiving accounts, and tips. Provide a preview of
  what each choice changes. Use progressive disclosure; do not show tip payouts
  or cashier controls where they are disabled.
- Keep Chekmi's current colors, typography, iPhone navigation, and motion.
  Change labels, visibility, and sequence through one shared capability-driven
  shell. Avoid a separate hard-coded screen tree for each industry.

## Safe delivery sequence

| Phase | Work | Acceptance evidence |
| --- | --- | --- |
| 0. Restore demo | Deploy a reachable Chekmi backend and `chekmi-demo`; configure its private key and database RPCs. The endpoint returned HTTP 404 on 16 October 2026. Keep a guided, clearly illustrative preview separate from live receipt checks. | Demo GET reports ready; a real demo lookup succeeds without writing a business ticket; quota and duplicate checks pass. Apple requires live backend services and review access for account-based apps: [App Review Guidelines, 2.1](https://developer.apple.com/app-store/review/guidelines/). |
| 1. Generalize copy and setup | Replace “restaurant,” “waiter,” “table,” and “tip” where they are presented as universal. Add the short personal/team setup and generic reference defaults; keep existing workspaces on their present screens. | Shop, solo, service, and restaurant usability walkthroughs; English and Amharic review; camera/manual and narrow iPhone layouts pass. |
| 2. Add capability and workflow model | Introduce workspace profile, capability checks, and automatic/review completion policy behind a feature flag. Map old roles to the equivalent permissions during transition. | Server authorization matrix and tenant-isolation tests; cashier-only login can verify when allowed; unauthorized users cannot gain rights by altering client state. |
| 3. Fix money semantics | Make excess amount and tip separate, add typed references and neutral actor fields, migrate reads before writes, and preserve immutable events. | Historical records unchanged; new overpayment is never silently paid as a tip; duplicate and uncertain-response recovery still pass. |
| 4. Open solo onboarding | Add owner self-registration, one-member workspace creation, recovery, and deletion; decouple seat count from review/tip features in plans. | Fresh solo account can configure a destination and verify without a cashier; deletion and audit-retention behavior is tested. |
| 5. Release gradually | Pilot the new modes with existing businesses and a few solo users, then enable by cohort. Maintain a rollback switch for presentation and workflow configuration. | Real receipts on physical iPhones; no regression in restaurant settlement/tips; queue latency, errors, and support cases monitored. |

The first publishable version can support **solo, one-cashier, and team** flows
with generic references. Restaurant tables and tips can remain optional modules.
Avoid advertising personal self-registration until phase 4 is shipped. Do not
remove legacy database columns or force existing businesses onto new policies
in the first migration.
