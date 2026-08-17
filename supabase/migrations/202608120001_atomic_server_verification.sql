-- Server-authoritative verification evidence and atomic ticket creation.
-- Only the backend service role may execute these functions. Flutter clients
-- continue to read tenant-scoped tickets through list_tickets.

alter table public.tickets
  add column if not exists expected_amount numeric,
  add column if not exists verified_amount numeric,
  add column if not exists provider_transaction_at timestamptz,
  add column if not exists payer_name text,
  add column if not exists payer_account text,
  add column if not exists receiver_name text,
  add column if not exists receiver_account text,
  add column if not exists verification_evidence_id uuid;

create table if not exists public.payment_verification_evidence (
  evidence_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  staff_number text not null,
  provider text not null,
  transaction_ref text not null,
  expected_amount numeric not null check (expected_amount > 0),
  verified_amount numeric not null check (verified_amount >= expected_amount),
  tip_amount numeric not null check (tip_amount >= 0),
  currency text not null default 'ETB',
  receiver_account text not null,
  receiver_name text,
  payer_account text,
  payer_name text,
  provider_transaction_at timestamptz,
  provider_status text,
  provider_payload jsonb not null,
  created_at timestamptz not null default now(),
  unique (business_id,provider,transaction_ref)
);
create index if not exists payment_evidence_business_created_idx
  on public.payment_verification_evidence (business_id,created_at desc);
alter table public.payment_verification_evidence enable row level security;
revoke all on public.payment_verification_evidence from anon,authenticated;

do $$ begin
  if not exists (
    select 1 from pg_constraint where conname='tickets_verification_evidence_fk'
  ) then
    alter table public.tickets add constraint tickets_verification_evidence_fk
      foreign key (verification_evidence_id)
      references public.payment_verification_evidence(evidence_id);
  end if;
end $$;

create or replace function public.get_verification_context(
  p_token text,p_provider text
) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; accounts jsonb; provider_key text; account_value text;
begin
  s:=public.require_staff_session(p_token);
  if s.role not in ('waiter','admin') then
    raise exception 'Role is not allowed to verify receipts' using errcode='42501';
  end if;
  provider_key:=lower(regexp_replace(coalesce(p_provider,''),'[^a-z0-9]','','g'));
  select coalesce(b.bank_accounts,'{}'::jsonb) into accounts
  from public.businesses b where b.business_id=s.business_id and b.is_active;
  account_value:=case provider_key
    when 'telebirr' then accounts->>'telebirr_number'
    when 'cbe' then accounts->>'cbe_number'
    when 'cbebirr' then accounts->>'cbebirr_number'
    when 'dashen' then accounts->>'dashen_number'
    when 'abyssinia' then accounts->>'abyssinia_number'
    when 'mpesa' then accounts->>'mpesa_number'
    else null
  end;
  if nullif(btrim(coalesce(account_value,'')),'') is null then
    raise exception 'This payment method is not configured for the business'
      using errcode='22023';
  end if;
  return jsonb_build_object(
    'business_id',s.business_id,'staff_number',s.staff_number,'role',s.role,
    'provider',provider_key,'receiving_account',account_value
  );
end $$;

create or replace function public.commit_verified_payment(
  p_token text,p_provider text,p_transaction_ref text,p_table_number text,
  p_expected_amount numeric,p_verified_amount numeric,p_currency text,
  p_receiver_account text,p_receiver_name text,p_payer_account text,p_payer_name text,
  p_provider_transaction_at timestamptz,p_provider_status text,p_provider_payload jsonb,
  p_receipt_image_base64 text
) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare
  s public.staff_sessions;
  evidence public.payment_verification_evidence;
  created public.tickets;
  receipt_bytes bytea;
  normalized_provider text;
  normalized_ref text;
  tip numeric;
begin
  s:=public.require_staff_session(p_token);
  if s.role not in ('waiter','admin') then
    raise exception 'Role is not allowed to create verified tickets' using errcode='42501';
  end if;
  normalized_provider:=lower(regexp_replace(coalesce(p_provider,''),'[^a-z0-9]','','g'));
  if normalized_provider not in ('telebirr','cbe','cbebirr','dashen','abyssinia','mpesa') then
    raise exception 'Unsupported payment provider' using errcode='22023';
  end if;
  normalized_ref:=upper(btrim(coalesce(p_transaction_ref,'')));
  if normalized_ref='' or btrim(coalesce(p_table_number,''))='' then
    raise exception 'Transaction reference and table are required' using errcode='22023';
  end if;
  if p_expected_amount is null or p_expected_amount <= 0 or
     p_verified_amount is null or p_verified_amount < p_expected_amount then
    raise exception 'Verified payment amount is invalid' using errcode='22023';
  end if;
  if btrim(coalesce(p_receiver_account,''))='' then
    raise exception 'Verified receiver account is required' using errcode='22023';
  end if;
  tip:=p_verified_amount-p_expected_amount;

  if nullif(btrim(coalesce(p_receipt_image_base64,'')),'') is not null then
    begin
      receipt_bytes:=decode(p_receipt_image_base64,'base64');
    exception when others then
      raise exception 'Receipt image is not valid base64' using errcode='22023';
    end;
    if octet_length(receipt_bytes) > 1500000 then
      raise exception 'Compressed receipt image exceeds 1.5 MB' using errcode='22023';
    end if;
  end if;

  insert into public.payment_verification_evidence(
    business_id,staff_number,provider,transaction_ref,expected_amount,verified_amount,
    tip_amount,currency,receiver_account,receiver_name,payer_account,payer_name,
    provider_transaction_at,provider_status,provider_payload
  ) values (
    s.business_id,s.staff_number,normalized_provider,normalized_ref,p_expected_amount,
    p_verified_amount,tip,coalesce(nullif(btrim(p_currency),''),'ETB'),
    btrim(p_receiver_account),nullif(btrim(coalesce(p_receiver_name,'')),''),
    nullif(btrim(coalesce(p_payer_account,'')),''),nullif(btrim(coalesce(p_payer_name,'')),''),
    p_provider_transaction_at,nullif(btrim(coalesce(p_provider_status,'')),''),
    coalesce(p_provider_payload,'{}'::jsonb)
  ) returning * into evidence;

  insert into public.tickets(
    business_id,waiter_id,table_number,transaction_ref,bill_amount,expected_amount,
    verified_amount,tip_amount,bank,status,receipt_image_saved,
    provider_transaction_at,payer_name,payer_account,receiver_name,receiver_account,
    verification_evidence_id
  ) values (
    s.business_id,s.staff_number,btrim(p_table_number),normalized_ref,p_expected_amount,
    p_expected_amount,p_verified_amount,tip,normalized_provider,'pending',
    receipt_bytes is not null,p_provider_transaction_at,p_payer_name,p_payer_account,
    p_receiver_name,p_receiver_account,evidence.evidence_id
  ) returning * into created;

  if receipt_bytes is not null then
    insert into public.receipt_images(
      business_id,ticket_id,waiter_id,mime_type,byte_size,sha256,image_data
    ) values (
      s.business_id,created.ticket_id,s.staff_number,'image/jpeg',
      octet_length(receipt_bytes),encode(extensions.digest(receipt_bytes,'sha256'),'hex'),
      receipt_bytes
    );
  end if;

  insert into public.verification_attempts(
    business_id,staff_number,provider,transaction_ref,expected_amount,
    verified_amount,tip_amount,outcome,error_message
  ) values (
    s.business_id,s.staff_number,normalized_provider,normalized_ref,p_expected_amount,
    p_verified_amount,tip,'verified',null
  );

  return jsonb_build_object(
    'ticket_id',created.ticket_id,'evidence_id',evidence.evidence_id,
    'provider',normalized_provider,'reference',normalized_ref,
    'expected_amount',p_expected_amount,'verified_amount',p_verified_amount,
    'tip_amount',tip,'receipt_saved',receipt_bytes is not null
  );
exception when unique_violation then
  raise exception 'This payment reference was already verified'
    using errcode='23505';
end $$;

revoke all on function public.get_verification_context(text,text) from public,anon,authenticated;
revoke all on function public.commit_verified_payment(
  text,text,text,text,numeric,numeric,text,text,text,text,text,timestamptz,text,jsonb,text
) from public,anon,authenticated;
grant execute on function public.get_verification_context(text,text) to service_role;
grant execute on function public.commit_verified_payment(
  text,text,text,text,numeric,numeric,text,text,text,text,text,timestamptz,text,jsonb,text
) to service_role;

-- The client-controlled create_ticket variants are retired. The backend calls
-- commit_verified_payment only after authoritative upstream verification.
revoke execute on function public.create_ticket(text,text,numeric,text,text,numeric)
  from anon,authenticated;
revoke execute on function public.create_ticket(text,text,numeric,text,text,numeric,text)
  from anon,authenticated;
revoke execute on function public.record_verification_attempt(text,text,text,numeric,numeric,numeric,text,text)
  from anon,authenticated;
