-- Payment correctness hardening: provider-date evidence, server-recorded
-- failures, and idempotent recovery after a client/network timeout.

alter table public.verification_attempts
  add column if not exists error_code text;

alter table public.payment_verification_evidence
  drop constraint if exists payment_evidence_provider_date_required;
alter table public.payment_verification_evidence
  add constraint payment_evidence_provider_date_required
  check (provider_transaction_at is not null) not valid;

create or replace function public.find_committed_payment(
  p_token text,p_provider text,p_transaction_ref text
) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare
  s public.staff_sessions;
  provider_key text;
  reference_key text;
  result jsonb;
begin
  s:=public.require_staff_session(p_token);
  if s.role not in ('waiter','admin') then
    raise exception 'Role is not allowed to recover verified tickets' using errcode='42501';
  end if;
  provider_key:=lower(regexp_replace(coalesce(p_provider,''),'[^a-z0-9]','','g'));
  reference_key:=upper(btrim(coalesce(p_transaction_ref,'')));
  if provider_key not in ('telebirr','cbe','cbebirr','dashen','abyssinia','mpesa') or
     reference_key='' then
    raise exception 'Provider and transaction reference are required' using errcode='22023';
  end if;

  select jsonb_build_object(
    'ticket_id',t.ticket_id,
    'evidence_id',e.evidence_id,
    'provider',e.provider,
    'reference',e.transaction_ref,
    'expected_amount',e.expected_amount,
    'verified_amount',e.verified_amount,
    'tip_amount',e.tip_amount,
    'currency',e.currency,
    'receipt_saved',t.receipt_image_saved,
    'provider_transaction_at',e.provider_transaction_at,
    'created_at',e.created_at
  ) into result
  from public.payment_verification_evidence e
  join public.tickets t on t.verification_evidence_id=e.evidence_id
  where e.business_id=s.business_id
    and e.provider=provider_key
    and (
      e.transaction_ref=reference_key or
      upper(coalesce(e.provider_payload#>>'{verificationRequest,submittedReference}',''))=reference_key
    )
  limit 1;
  return result;
end $$;

create or replace function public.service_record_failed_verification(
  p_token text,p_provider text,p_transaction_ref text,p_expected_amount numeric,
  p_verified_amount numeric,p_error_code text,p_error_message text
) returns uuid
language plpgsql security definer set search_path=public,extensions as $$
declare
  s public.staff_sessions;
  provider_key text;
  created_id uuid;
begin
  s:=public.require_staff_session(p_token);
  if s.role not in ('waiter','admin') then
    raise exception 'Role is not allowed to verify receipts' using errcode='42501';
  end if;
  provider_key:=lower(regexp_replace(coalesce(p_provider,''),'[^a-z0-9]','','g'));
  if provider_key not in ('telebirr','cbe','cbebirr','dashen','abyssinia','mpesa') then
    raise exception 'Unsupported payment provider' using errcode='22023';
  end if;

  insert into public.verification_attempts(
    business_id,staff_number,provider,transaction_ref,expected_amount,
    verified_amount,tip_amount,outcome,error_code,error_message
  ) values (
    s.business_id,s.staff_number,provider_key,
    nullif(upper(btrim(coalesce(p_transaction_ref,''))),''),
    p_expected_amount,p_verified_amount,0,'failed',
    nullif(left(btrim(coalesce(p_error_code,'')),80),''),
    nullif(left(btrim(coalesce(p_error_message,'')),500),'')
  ) returning attempt_id into created_id;
  return created_id;
end $$;

revoke all on function public.find_committed_payment(text,text,text)
  from public,anon,authenticated;
grant execute on function public.find_committed_payment(text,text,text)
  to service_role;

revoke all on function public.service_record_failed_verification(
  text,text,text,numeric,numeric,text,text
) from public,anon,authenticated;
grant execute on function public.service_record_failed_verification(
  text,text,text,numeric,numeric,text,text
) to service_role;
