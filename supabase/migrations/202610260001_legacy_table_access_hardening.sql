-- Additive hardening for legacy public tables found during master reconciliation.
-- Existing rows, functions, triggers, and policies are preserved.
-- Service-owned/security-definer RPCs continue to access these tables.
do $$
declare table_name text;
begin
  foreach table_name in array array[
    'app_sessions','staff_sessions','super_admins',
    'ticket_audit_logs','verified_transactions'
  ] loop
    if to_regclass('public.' || table_name) is not null then
      -- Preserve backend service access when removing inherited PUBLIC grants.
      execute format('grant all on table public.%I to service_role',table_name);
      execute format('alter table public.%I enable row level security',table_name);
      execute format('revoke all on table public.%I from public, anon, authenticated',table_name);
    end if;
  end loop;
end $$;

-- These are trigger helpers, never client RPCs. Do not replace their bodies.
revoke all on function public.create_missing_receipt_evidence()
  from public,anon,authenticated;
revoke all on function public.protect_archived_receipt_original()
  from public,anon,authenticated;
revoke all on function public.reject_known_cross_workspace_payment_duplicate()
  from public,anon,authenticated;
