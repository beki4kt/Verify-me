-- Admin reporting metadata, secure receipt evidence, and waiter tip payouts.

alter table public.businesses
  add column if not exists business_type text not null default 'Restaurant';

alter table public.tickets
  add column if not exists receipt_image_saved boolean not null default false;

create table if not exists public.receipt_images (
  receipt_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  ticket_id uuid not null unique references public.tickets(ticket_id) on delete cascade,
  waiter_id text not null,
  mime_type text not null check (mime_type in ('image/jpeg','image/png')),
  byte_size integer not null check (byte_size between 1 and 1500000),
  sha256 text not null,
  image_data bytea not null,
  created_at timestamptz not null default now()
);
create index if not exists receipt_images_business_created_idx
  on public.receipt_images (business_id,created_at desc);
alter table public.receipt_images enable row level security;
revoke all on public.receipt_images from anon,authenticated;

create table if not exists public.tip_withdrawal_requests (
  request_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  staff_number text not null,
  amount numeric not null check (amount > 0),
  status text not null default 'pending'
    check (status in ('pending','approved','rejected')),
  requested_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by text
);
create index if not exists tip_withdrawals_business_status_idx
  on public.tip_withdrawal_requests (business_id,status,requested_at desc);
create index if not exists tip_withdrawals_waiter_idx
  on public.tip_withdrawal_requests (business_id,staff_number,requested_at desc);
alter table public.tip_withdrawal_requests enable row level security;
revoke all on public.tip_withdrawal_requests from anon,authenticated;

create or replace function public.create_ticket(
  p_token text, p_transaction_ref text, p_bill_amount numeric,
  p_bank text, p_table_number text, p_tip_amount numeric,
  p_receipt_image_base64 text
) returns public.tickets
language plpgsql security definer set search_path=public,extensions as $$
declare
  s public.staff_sessions;
  created public.tickets;
  receipt_bytes bytea;
begin
  s:=public.require_staff_session(p_token);
  if s.role not in ('waiter','admin') then
    raise exception 'Role is not allowed to create tickets' using errcode='42501';
  end if;
  if btrim(coalesce(p_table_number,''))='' then
    raise exception 'Table number is required' using errcode='22023';
  end if;
  if p_bill_amount is null or p_bill_amount <= 0 then
    raise exception 'Bill amount must be positive' using errcode='22023';
  end if;
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

  insert into public.tickets(
    business_id,waiter_id,table_number,transaction_ref,bill_amount,tip_amount,
    bank,status,receipt_image_saved
  ) values (
    s.business_id,s.staff_number,btrim(p_table_number),upper(btrim(p_transaction_ref)),
    p_bill_amount,greatest(coalesce(p_tip_amount,0),0),btrim(p_bank),'pending',
    receipt_bytes is not null
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
  return created;
end $$;

create or replace function public.get_receipt_image(p_token text,p_ticket_id uuid)
returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; receipt public.receipt_images;
begin
  s:=public.require_staff_session(p_token);
  select r.* into receipt from public.receipt_images r
  where r.ticket_id=p_ticket_id and r.business_id=s.business_id
    and (s.role='admin' or r.waiter_id=s.staff_number);
  if not found then return null; end if;
  return jsonb_build_object(
    'mime_type',receipt.mime_type,
    'byte_size',receipt.byte_size,
    'sha256',receipt.sha256,
    'image_base64',encode(receipt.image_data,'base64')
  );
end $$;

create or replace function public.request_tip_withdrawal(
  p_token text,p_amount numeric
) returns public.tip_withdrawal_requests
language plpgsql security definer set search_path=public,extensions as $$
declare
  s public.staff_sessions;
  earned numeric;
  committed numeric;
  created public.tip_withdrawal_requests;
begin
  s:=public.require_staff_session(p_token);
  if s.role <> 'waiter' then
    raise exception 'Only waiters can request tip withdrawals' using errcode='42501';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Withdrawal amount must be positive' using errcode='22023';
  end if;
  select coalesce(sum(t.tip_amount),0) into earned from public.tickets t
    where t.business_id=s.business_id and t.waiter_id=s.staff_number
      and t.status='settled';
  select coalesce(sum(w.amount),0) into committed
    from public.tip_withdrawal_requests w
    where w.business_id=s.business_id and w.staff_number=s.staff_number
      and w.status in ('pending','approved');
  if p_amount > earned-committed then
    raise exception 'Withdrawal amount exceeds the available tip balance'
      using errcode='22023';
  end if;
  insert into public.tip_withdrawal_requests(business_id,staff_number,amount)
  values(s.business_id,s.staff_number,p_amount) returning * into created;
  return created;
end $$;

create or replace function public.list_tip_withdrawal_requests(p_token text)
returns setof public.tip_withdrawal_requests
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if s.role='admin' then
    return query select w.* from public.tip_withdrawal_requests w
      where w.business_id=s.business_id order by w.requested_at desc limit 100;
  end if;
  return query select w.* from public.tip_withdrawal_requests w
    where w.business_id=s.business_id and w.staff_number=s.staff_number
    order by w.requested_at desc limit 50;
end $$;

create or replace function public.resolve_tip_withdrawal_request(
  p_token text,p_request_id uuid,p_status text
) returns public.tip_withdrawal_requests
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; changed public.tip_withdrawal_requests;
begin
  s:=public.require_staff_session(p_token);
  if s.role <> 'admin' then
    raise exception 'Only an administrator can resolve withdrawals' using errcode='42501';
  end if;
  if p_status not in ('approved','rejected') then
    raise exception 'Invalid withdrawal status' using errcode='22023';
  end if;
  update public.tip_withdrawal_requests set
    status=p_status,resolved_at=now(),resolved_by=s.staff_number
  where request_id=p_request_id and business_id=s.business_id and status='pending'
  returning * into changed;
  if not found then
    raise exception 'Pending withdrawal request not found' using errcode='P0002';
  end if;
  return changed;
end $$;

revoke all on function public.create_ticket(text,text,numeric,text,text,numeric,text) from public;
revoke all on function public.get_receipt_image(text,uuid) from public;
revoke all on function public.request_tip_withdrawal(text,numeric) from public;
revoke all on function public.list_tip_withdrawal_requests(text) from public;
revoke all on function public.resolve_tip_withdrawal_request(text,uuid,text) from public;
grant execute on function public.create_ticket(text,text,numeric,text,text,numeric,text) to anon,authenticated;
grant execute on function public.get_receipt_image(text,uuid) to anon,authenticated;
grant execute on function public.request_tip_withdrawal(text,numeric) to anon,authenticated;
grant execute on function public.list_tip_withdrawal_requests(text) to anon,authenticated;
grant execute on function public.resolve_tip_withdrawal_request(text,uuid,text) to anon,authenticated;
