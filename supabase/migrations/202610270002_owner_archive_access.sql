-- Separate read-only owner access when paid verification is unavailable.
-- This does not change require_staff_session or any payment write function.
-- Apply only after review on the shared prelaunch project.

create or replace function public.owner_archive_business_id() returns uuid
language plpgsql stable security definer set search_path=public,auth as $$
declare owner_id uuid := auth.uid(); result uuid;
begin
  if owner_id is null then
    raise exception 'Sign in first' using errcode='42501';
  end if;
  select oi.business_id into result
  from public.workspace_owner_identities oi
  join public.staff st on st.business_id=oi.business_id
    and st.staff_number=oi.staff_number and st.is_active
  join auth.users u on u.id=oi.auth_user_id
  where oi.auth_user_id=owner_id
    and (u.email_confirmed_at is not null or
      (u.phone_confirmed_at is not null and u.phone=st.phone_number));
  if result is null then
    raise exception 'Owner access unavailable' using errcode='42501';
  end if;
  return result;
end $$;

create or replace function public.owner_historical_receipts() returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare owner_business_id uuid := public.owner_archive_business_id(); result jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
    'ticket_id',x.ticket_id,'verified_amount',x.verified_amount,
    'currency',x.currency,'provider',x.provider,
    'transaction_reference',x.transaction_ref,
    'transaction_at',x.provider_transaction_at,
    'verified_at',x.verified_at,'completion_status',x.status,
    'reference_kind',x.reference_kind,'reference_value',x.reference_value)
    order by x.verified_at desc),'[]'::jsonb) into result
  from (
    select t.ticket_id,t.status,t.reference_kind,t.reference_value,
      e.verified_amount,e.currency,e.provider,e.transaction_ref,
      e.provider_transaction_at,e.created_at as verified_at
    from public.tickets t
    join public.payment_verification_evidence e
      on e.evidence_id=t.verification_evidence_id
      and e.business_id=t.business_id
    where t.business_id=owner_business_id
    order by e.created_at desc limit 100
  ) x;
  return result;
end $$;

create or replace function public.owner_historical_receipt_detail(
  p_ticket_id uuid
) returns jsonb language plpgsql stable security definer
set search_path=public as $$
declare owner_business_id uuid := public.owner_archive_business_id(); result jsonb;
begin
  select jsonb_build_object(
    'ticket_id',t.ticket_id,'verified_amount',e.verified_amount,
    'expected_amount',e.expected_amount,'currency',e.currency,
    'provider',e.provider,'transaction_reference',e.transaction_ref,
    'transaction_at',e.provider_transaction_at,'verified_at',e.created_at,
    'completion_status',t.status,'reference_kind',t.reference_kind,
    'reference_value',t.reference_value,
    'evidence_status',coalesce(r.storage_status,'missing_original'),
    'original_access','requires_authorized_receipt_service'
  ) into result
  from public.tickets t
  join public.payment_verification_evidence e
    on e.evidence_id=t.verification_evidence_id
    and e.business_id=t.business_id
  left join public.receipt_images r
    on r.ticket_id=t.ticket_id and r.business_id=t.business_id
  where t.ticket_id=p_ticket_id and t.business_id=owner_business_id;
  return result;
end $$;

revoke all on function public.owner_archive_business_id() from public,anon;
revoke all on function public.owner_historical_receipts() from public,anon;
revoke all on function public.owner_historical_receipt_detail(uuid)
  from public,anon;
grant execute on function public.owner_archive_business_id() to authenticated;
grant execute on function public.owner_historical_receipts() to authenticated;
grant execute on function public.owner_historical_receipt_detail(uuid)
  to authenticated;
