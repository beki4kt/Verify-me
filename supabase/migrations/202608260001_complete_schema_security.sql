-- Final schema marker, defense-in-depth RLS, legal-document visibility, and
-- an executable assertion that every RPC used by the current Flutter and
-- TypeScript applications exists.

create table if not exists public.chekmi_schema_meta (
  singleton boolean primary key default true check (singleton),
  schema_version text not null,
  applied_at timestamptz not null default now()
);
alter table public.chekmi_schema_meta enable row level security;
revoke all on public.chekmi_schema_meta from public,anon,authenticated;

insert into public.chekmi_schema_meta(singleton,schema_version,applied_at)
values(true,'2026-08-26.1',now())
on conflict(singleton) do update set
  schema_version=excluded.schema_version,
  applied_at=excluded.applied_at;

alter table public.businesses enable row level security;
alter table public.staff enable row level security;
alter table public.tickets enable row level security;
grant usage on schema public to anon,authenticated,service_role;
revoke all on public.businesses from anon,authenticated;
revoke all on public.staff from anon,authenticated;
revoke all on public.tickets from anon,authenticated;

-- Legal copy is the only table intentionally readable by public clients.
-- Every tenant-owned or financial table remains RPC-only.
drop policy if exists legal_documents_read_current on public.legal_documents;
create policy legal_documents_read_current on public.legal_documents
  for select to anon,authenticated using (is_current);
grant select on public.legal_documents to anon,authenticated;

-- Trigger/helper functions are internal implementation details.
revoke all on function public.hash_staff_password() from public,anon,authenticated;
revoke all on function public.require_staff_session(text) from public,anon,authenticated;
revoke all on function public.prevent_financial_evidence_mutation() from public,anon,authenticated;
revoke all on function public.protect_verified_ticket_values() from public,anon,authenticated;
revoke all on function public.subscription_has_access(public.businesses) from public,anon,authenticated;

do $$
declare
  required_table text;
  required_function text;
  client_function text;
  service_function text;
begin
  foreach required_table in array array[
    'businesses','staff','tickets','staff_sessions','verification_attempts',
    'receipt_images','tip_withdrawal_requests','payment_verification_evidence',
    'security_audit_log','ticket_financial_events','tip_payout_ledger',
    'subscription_invoices','subscription_payments','legal_documents',
    'staff_consents','business_data_retention','support_cases',
    'account_deletion_requests','operator_audit_log','chekmi_schema_meta'
  ] loop
    if to_regclass('public.'||required_table) is null then
      raise exception 'Required CHEKMI table is missing: %',required_table;
    end if;
  end loop;

  foreach required_function in array array[
    'public.lookup_business(text)',
    'public.login_staff(uuid,text,text)',
    'public.logout_staff(text)',
    'public.get_current_business(text)',
    'public.list_staff_roster(text)',
    'public.update_bank_accounts(text,jsonb)',
    'public.create_staff_member(text,text,text,text,text,text)',
    'public.update_staff_member(text,text,text,text,text,text)',
    'public.set_staff_active(text,text,boolean)',
    'public.change_current_admin_password(text,text,text)',
    'public.list_my_sessions(text)',
    'public.revoke_staff_session(text,uuid)',
    'public.list_tickets(text,text)',
    'public.get_receipt_image(text,uuid)',
    'public.list_my_verification_attempts(text)',
    'public.transition_verified_ticket(text,uuid,text,text)',
    'public.record_ticket_financial_action(text,uuid,text,text)',
    'public.list_ticket_report(text,timestamptz,timestamptz,text,text)',
    'public.request_tip_withdrawal(text,numeric)',
    'public.list_tip_withdrawal_requests(text)',
    'public.resolve_tip_withdrawal_request(text,uuid,text)',
    'public.get_subscription_summary(text)',
    'public.list_subscription_history(text)',
    'public.accept_legal_document(text,text,text)',
    'public.open_support_case(text,text,text,text,text)',
    'public.list_my_support_cases(text)',
    'public.request_business_deletion(text,text)',
    'public.get_verification_context(text,text)',
    'public.find_committed_payment(text,text,text)',
    'public.service_record_failed_verification(text,text,text,numeric,numeric,text,text)',
    'public.commit_verified_payment(text,text,text,text,numeric,numeric,text,text,text,text,text,timestamptz,text,jsonb,text)',
    'public.service_update_subscription(uuid,text,text,timestamptz,timestamptz,timestamptz,integer,boolean)',
    'public.service_create_subscription_invoice(uuid,text,text,numeric,text,timestamptz,timestamptz,timestamptz)',
    'public.service_record_subscription_payment(uuid,numeric,text,text,jsonb)',
    'public.service_refresh_subscription_statuses()',
    'public.service_operator_record_audit(text,text,text,text,jsonb)',
    'public.service_operator_snapshot()',
    'public.service_operator_create_business(text,text,text,text,text,text,integer,boolean,text,text,text,text)',
    'public.service_operator_set_business_active(text,uuid,boolean,text)',
    'public.service_operator_update_subscription(text,uuid,text,text,timestamptz,timestamptz,integer,boolean)',
    'public.service_operator_revoke_business_sessions(text,uuid,text)',
    'public.service_operator_update_support_case(text,uuid,text)',
    'public.service_operator_review_deletion(text,uuid,text,text)'
  ] loop
    if to_regprocedure(required_function) is null then
      raise exception 'Required CHEKMI function is missing: %',required_function;
    end if;
  end loop;

  foreach client_function in array array[
    'public.lookup_business(text)',
    'public.login_staff(uuid,text,text)',
    'public.logout_staff(text)',
    'public.get_current_business(text)',
    'public.list_staff_roster(text)',
    'public.update_bank_accounts(text,jsonb)',
    'public.create_staff_member(text,text,text,text,text,text)',
    'public.update_staff_member(text,text,text,text,text,text)',
    'public.set_staff_active(text,text,boolean)',
    'public.change_current_admin_password(text,text,text)',
    'public.list_my_sessions(text)',
    'public.revoke_staff_session(text,uuid)',
    'public.list_tickets(text,text)',
    'public.get_receipt_image(text,uuid)',
    'public.list_my_verification_attempts(text)',
    'public.transition_verified_ticket(text,uuid,text,text)',
    'public.record_ticket_financial_action(text,uuid,text,text)',
    'public.list_ticket_report(text,timestamptz,timestamptz,text,text)',
    'public.request_tip_withdrawal(text,numeric)',
    'public.list_tip_withdrawal_requests(text)',
    'public.resolve_tip_withdrawal_request(text,uuid,text)',
    'public.get_subscription_summary(text)',
    'public.list_subscription_history(text)',
    'public.accept_legal_document(text,text,text)',
    'public.open_support_case(text,text,text,text,text)',
    'public.list_my_support_cases(text)',
    'public.request_business_deletion(text,text)'
  ] loop
    if not has_function_privilege('anon',client_function,'EXECUTE') then
      raise exception 'Anonymous app role cannot execute required RPC: %',client_function;
    end if;
  end loop;

  foreach service_function in array array[
    'public.get_verification_context(text,text)',
    'public.find_committed_payment(text,text,text)',
    'public.service_record_failed_verification(text,text,text,numeric,numeric,text,text)',
    'public.commit_verified_payment(text,text,text,text,numeric,numeric,text,text,text,text,text,timestamptz,text,jsonb,text)',
    'public.service_update_subscription(uuid,text,text,timestamptz,timestamptz,timestamptz,integer,boolean)',
    'public.service_create_subscription_invoice(uuid,text,text,numeric,text,timestamptz,timestamptz,timestamptz)',
    'public.service_record_subscription_payment(uuid,numeric,text,text,jsonb)',
    'public.service_refresh_subscription_statuses()',
    'public.service_operator_record_audit(text,text,text,text,jsonb)',
    'public.service_operator_snapshot()',
    'public.service_operator_create_business(text,text,text,text,text,text,integer,boolean,text,text,text,text)',
    'public.service_operator_set_business_active(text,uuid,boolean,text)',
    'public.service_operator_update_subscription(text,uuid,text,text,timestamptz,timestamptz,integer,boolean)',
    'public.service_operator_revoke_business_sessions(text,uuid,text)',
    'public.service_operator_update_support_case(text,uuid,text)',
    'public.service_operator_review_deletion(text,uuid,text,text)'
  ] loop
    if not has_function_privilege('service_role',service_function,'EXECUTE') then
      raise exception 'Backend service role cannot execute required RPC: %',service_function;
    end if;
    if has_function_privilege('anon',service_function,'EXECUTE') then
      raise exception 'Server-only RPC is exposed to the anonymous role: %',service_function;
    end if;
  end loop;

  if has_table_privilege('anon','public.businesses','SELECT') or
     has_table_privilege('anon','public.staff','SELECT') or
     has_table_privilege('anon','public.tickets','SELECT') then
    raise exception 'A tenant-owned base table is directly readable by the anonymous role';
  end if;
end $$;

notify pgrst,'reload schema';
