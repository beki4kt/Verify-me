-- Phase 2: preserve every historical ticket.tip_amount and payout, while
-- requiring an explicit, authorized allocation for all future excess.
-- The commit RPC already records excess as unresolved for this policy.
begin;

update public.workspace_profiles
set overpayment_policy = 'unresolved', updated_at = now()
where overpayment_policy = 'legacy_tip';

-- Do not let a later service-role edit silently re-enable the old behavior.
alter table public.workspace_profiles
  add constraint future_excess_requires_explicit_allocation
  check (overpayment_policy = 'unresolved') not valid;
alter table public.workspace_profiles
  validate constraint future_excess_requires_explicit_allocation;

commit;
