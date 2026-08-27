create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
alter extension pgcrypto set schema extensions;

alter table public.businesses add column if not exists subscription_tier text not null default 'starter';
alter table public.businesses add column if not exists max_staff_limit integer not null default 5;
alter table public.businesses add column if not exists has_cashier_module boolean not null default false;
alter table public.businesses add column if not exists is_active boolean not null default true;
alter table public.businesses add column if not exists bank_accounts jsonb not null default '{}'::jsonb;
alter table public.staff add column if not exists password_hash text;
alter table public.staff add column if not exists is_active boolean not null default true;
alter table public.tickets add column if not exists bank text;
alter table public.tickets add column if not exists transaction_ref text;
alter table public.tickets add column if not exists tip_amount numeric not null default 0;
alter table public.tickets add column if not exists actual_amount numeric;
alter table public.tickets add column if not exists updated_at timestamptz not null default now();

-- Some collaborator schemas called this field bank_name. Preserve existing
-- values while standardizing on the `bank` field used by the Flutter client.
do $$ begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='tickets' and column_name='bank_name'
  ) then
    execute 'update public.tickets set bank=bank_name where bank is null';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='tickets' and column_name='transaction_id'
  ) then
    execute 'update public.tickets set transaction_ref=transaction_id::text where transaction_ref is null';
  elsif exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='tickets' and column_name='reference'
  ) then
    execute 'update public.tickets set transaction_ref=reference::text where transaction_ref is null';
  end if;
end $$;

create unique index if not exists tickets_provider_reference_unique
  on public.tickets (business_id, lower(bank), upper(transaction_ref))
  where bank is not null and transaction_ref is not null;

create table if not exists public.staff_sessions (
  session_id uuid primary key default extensions.gen_random_uuid(),
  token_hash bytea not null unique,
  business_id uuid references public.businesses(business_id) on delete cascade,
  staff_number text not null,
  role text not null,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.staff_sessions enable row level security;

-- Staff use the app's own short-lived session rather than Supabase Auth.
-- Permit active-business ticket operations through the public API while the
-- app session layer supplies the business/staff identifiers.
alter table public.tickets enable row level security;
drop policy if exists tickets_insert_active_business on public.tickets;
create policy tickets_insert_active_business on public.tickets
  for insert to anon, authenticated
  with check (exists (
    select 1 from public.businesses b
    where b.business_id = tickets.business_id and b.is_active = true
  ));
drop policy if exists tickets_select_active_business on public.tickets;
create policy tickets_select_active_business on public.tickets
  for select to anon, authenticated
  using (exists (
    select 1 from public.businesses b
    where b.business_id = tickets.business_id and b.is_active = true
  ));
drop policy if exists tickets_update_active_business on public.tickets;
create policy tickets_update_active_business on public.tickets
  for update to anon, authenticated
  using (exists (
    select 1 from public.businesses b
    where b.business_id = tickets.business_id and b.is_active = true
  ));

create or replace function public.hash_staff_password()
returns trigger language plpgsql security definer set search_path=public,extensions as $$
begin
  if new.password is not null and btrim(new.password) <> '' then
    new.password_hash := extensions.crypt(new.password,extensions.gen_salt('bf'));
    new.password := null;
  end if;
  return new;
end $$;
drop trigger if exists staff_hash_password on public.staff;
create trigger staff_hash_password before insert or update of password on public.staff
for each row execute function public.hash_staff_password();

create or replace function public.login_staff(p_business_id uuid,p_phone text,p_password text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare s record; raw_token text;
begin
  select st.*,b.name business_name,b.max_staff_limit,b.has_cashier_module into s
  from public.staff st join public.businesses b on b.business_id=st.business_id
  where st.business_id=p_business_id and st.phone_number=trim(p_phone)
    and st.is_active and b.is_active and
    ((st.password_hash is not null and extensions.crypt(p_password,st.password_hash)=st.password_hash)
      or (st.password_hash is null and st.password=p_password)) limit 1;
  if not found then return null; end if;
  if s.password_hash is null then
    update public.staff set password_hash=extensions.crypt(p_password,extensions.gen_salt('bf')),password=null
    where business_id=s.business_id and staff_number=s.staff_number;
  end if;
  raw_token:=encode(extensions.gen_random_bytes(32),'hex');
  insert into public.staff_sessions(token_hash,business_id,staff_number,role,expires_at)
  values(extensions.digest(convert_to(raw_token,'UTF8'),'sha256'),s.business_id,s.staff_number,s.role,now()+interval '12 hours');
  return jsonb_build_object('token',raw_token,'business_id',s.business_id,'business_name',s.business_name,
    'staff_number',s.staff_number,'role',s.role,'max_staff_limit',s.max_staff_limit,
    'has_cashier_module',s.has_cashier_module);
end $$;
revoke all on function public.login_staff(uuid,text,text) from public;
grant execute on function public.login_staff(uuid,text,text) to anon,authenticated;
