-- CHEKMI complete Supabase setup
-- Generated from base_schema.sql plus every dated migration.
-- Schema version: 2026-08-26.3
-- Safe to rerun; it does not insert demo businesses or known credentials.
-- Replace the legal-document YOUR_DOMAIN URLs before production launch.

begin;

-- Base schema
-- CHEKMI base schema.
--
-- The dated migrations were originally written against an existing pilot
-- database. This file supplies the three original tables so the generated
-- CHEKMI_COMPLETE_SETUP.sql bundle also works on a fresh Supabase project.
-- Existing installations are preserved: missing base columns and indexes are
-- added, while application data is never deleted or replaced.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
alter extension pgcrypto set schema extensions;

create table if not exists public.businesses (
  business_id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  business_code text not null,
  address text,
  created_at timestamptz not null default now()
);

alter table public.businesses
  add column if not exists business_id uuid default extensions.gen_random_uuid(),
  add column if not exists name text,
  add column if not exists business_code text,
  add column if not exists address text,
  add column if not exists created_at timestamptz default now();

update public.businesses
set business_code=upper(btrim(business_code))
where business_code is not null and business_code<>upper(btrim(business_code));

do $$
begin
  if exists (
    select 1 from public.businesses
    where business_id is null
       or nullif(btrim(name),'') is null
       or nullif(btrim(business_code),'') is null
       or created_at is null
  ) then
    raise exception 'Existing businesses contain missing IDs, names, codes, or creation dates';
  end if;
end $$;

alter table public.businesses
  alter column business_id set default extensions.gen_random_uuid(),
  alter column business_id set not null,
  alter column name set not null,
  alter column business_code set not null,
  alter column created_at set default now(),
  alter column created_at set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.businesses'::regclass and contype='p'
  ) then
    alter table public.businesses
      add constraint businesses_pkey primary key (business_id);
  end if;
end $$;

create unique index if not exists businesses_business_code_unique
  on public.businesses (business_code);
create unique index if not exists businesses_business_id_unique
  on public.businesses (business_id);

create table if not exists public.staff (
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  staff_number text not null,
  name text not null,
  phone_number text not null,
  password text,
  role text not null check (role in ('admin','cashier','waiter')),
  created_at timestamptz not null default now(),
  primary key (business_id,staff_number)
);

alter table public.staff
  add column if not exists business_id uuid,
  add column if not exists staff_number text,
  add column if not exists name text,
  add column if not exists phone_number text,
  add column if not exists password text,
  add column if not exists role text,
  add column if not exists created_at timestamptz default now();

-- Normalize recoverable values from the original pilot schema. This keeps all
-- rows and preserves tenant/staff identifiers. Missing phone numbers receive
-- deterministic non-phone placeholders; a later migration deactivates those
-- accounts until an administrator supplies the real numbers.
update public.staff
set
  staff_number=btrim(staff_number),
  name=coalesce(
    nullif(btrim(name),''),
    case
      when nullif(btrim(staff_number),'') is not null
        then 'Staff '||btrim(staff_number)
      else null
    end
  ),
  phone_number=coalesce(
    nullif(btrim(phone_number),''),
    'legacy-unset-'||substr(
      encode(
        extensions.digest(
          convert_to(business_id::text||':'||btrim(staff_number),'UTF8'),
          'sha256'
        ),
        'hex'
      ),
      1,
      16
    )
  ),
  role=case lower(regexp_replace(btrim(coalesce(role,'')),'[^a-z]','','g'))
    when 'admin' then 'admin'
    when 'administrator' then 'admin'
    when 'restaurantadmin' then 'admin'
    when 'cashier' then 'cashier'
    when 'cashierstaff' then 'cashier'
    when 'waiter' then 'waiter'
    when 'server' then 'waiter'
    else lower(btrim(role))
  end,
  created_at=coalesce(created_at,now())
where
  staff_number is distinct from btrim(staff_number)
  or name is distinct from coalesce(
    nullif(btrim(name),''),
    case
      when nullif(btrim(staff_number),'') is not null
        then 'Staff '||btrim(staff_number)
      else null
    end
  )
  or phone_number is distinct from coalesce(
    nullif(btrim(phone_number),''),
    'legacy-unset-'||substr(
      encode(
        extensions.digest(
          convert_to(business_id::text||':'||btrim(staff_number),'UTF8'),
          'sha256'
        ),
        'hex'
      ),
      1,
      16
    )
  )
  or role is distinct from case lower(regexp_replace(btrim(coalesce(role,'')),'[^a-z]','','g'))
    when 'admin' then 'admin'
    when 'administrator' then 'admin'
    when 'restaurantadmin' then 'admin'
    when 'cashier' then 'cashier'
    when 'cashierstaff' then 'cashier'
    when 'waiter' then 'waiter'
    when 'server' then 'waiter'
    else lower(btrim(role))
  end
  or created_at is null;

do $$
declare
  missing_business integer;
  missing_number integer;
  missing_name integer;
  missing_phone integer;
  invalid_role integer;
  missing_created integer;
begin
  select
    count(*) filter(where business_id is null),
    count(*) filter(where nullif(btrim(staff_number),'') is null),
    count(*) filter(where nullif(btrim(name),'') is null),
    count(*) filter(where nullif(btrim(phone_number),'') is null),
    count(*) filter(where role is null or role not in ('admin','cashier','waiter')),
    count(*) filter(where created_at is null)
  into
    missing_business,missing_number,missing_name,missing_phone,
    invalid_role,missing_created
  from public.staff;

  if missing_business+missing_number+missing_name+missing_phone+
     invalid_role+missing_created>0 then
    raise exception 'Legacy staff records need manual repair before CHEKMI setup'
      using detail=format(
        'missing_business_id=%s, missing_staff_number=%s, missing_name=%s, missing_phone=%s, invalid_role=%s, missing_created_at=%s',
        missing_business,missing_number,missing_name,missing_phone,
        invalid_role,missing_created
      ),
      hint='Repair only the reported fields in public.staff, then rerun the complete setup query.';
  end if;
end $$;

alter table public.staff
  alter column business_id set not null,
  alter column staff_number set not null,
  alter column name set not null,
  alter column phone_number set not null,
  alter column role set not null,
  alter column created_at set default now(),
  alter column created_at set not null;

create unique index if not exists staff_business_staff_number_unique
  on public.staff (business_id,staff_number);
create unique index if not exists staff_business_phone_unique
  on public.staff (business_id,phone_number);

create table if not exists public.tickets (
  ticket_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  waiter_id text not null,
  table_number text not null,
  bill_amount numeric not null check (bill_amount>0),
  status text not null default 'pending'
    check (status in ('pending','settled','rejected')),
  created_at timestamptz not null default now()
);

alter table public.tickets
  add column if not exists ticket_id uuid default extensions.gen_random_uuid(),
  add column if not exists business_id uuid,
  add column if not exists waiter_id text,
  add column if not exists table_number text,
  add column if not exists bill_amount numeric,
  add column if not exists status text default 'pending',
  add column if not exists created_at timestamptz default now();

do $$
begin
  if exists (
    select 1 from public.tickets
    where ticket_id is null
       or business_id is null
       or nullif(btrim(waiter_id),'') is null
       or nullif(btrim(table_number),'') is null
       or bill_amount is null or bill_amount<=0
       or status not in ('pending','settled','rejected')
       or created_at is null
  ) then
    raise exception 'Existing tickets contain incomplete or invalid base records';
  end if;
end $$;

alter table public.tickets
  alter column ticket_id set default extensions.gen_random_uuid(),
  alter column ticket_id set not null,
  alter column business_id set not null,
  alter column waiter_id set not null,
  alter column table_number set not null,
  alter column bill_amount set not null,
  alter column status set default 'pending',
  alter column status set not null,
  alter column created_at set default now(),
  alter column created_at set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.tickets'::regclass and contype='p'
  ) then
    alter table public.tickets
      add constraint tickets_pkey primary key (ticket_id);
  end if;
end $$;

create unique index if not exists tickets_ticket_id_unique
  on public.tickets (ticket_id);
create index if not exists tickets_business_created_idx
  on public.tickets (business_id,created_at desc);
create index if not exists tickets_business_status_created_idx
  on public.tickets (business_id,status,created_at desc);

-- Migration: 202608040001_restore_verifier.sql
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

-- Migration: 202608040002_secure_ticket_tenants.sql
-- Ticket access is authenticated with the opaque token issued by login_staff.
-- Direct anon/authenticated table access cannot safely enforce tenant identity
-- because Verify-Me uses its own staff sessions rather than Supabase Auth JWTs.

create or replace function public.require_staff_session(p_token text)
returns public.staff_sessions
language plpgsql
security definer
set search_path=public,extensions
as $$
declare s public.staff_sessions;
begin
  if p_token is null or length(p_token) < 32 then
    raise exception 'Invalid or expired staff session' using errcode='28000';
  end if;

  select ss.* into s
  from public.staff_sessions ss
  join public.businesses b on b.business_id=ss.business_id
  join public.staff st on st.business_id=ss.business_id and st.staff_number=ss.staff_number
  where ss.token_hash=extensions.digest(convert_to(p_token,'UTF8'),'sha256')
    and ss.revoked_at is null and ss.expires_at > now()
    and b.is_active and st.is_active;

  if not found then
    raise exception 'Invalid or expired staff session' using errcode='28000';
  end if;
  return s;
end $$;
revoke all on function public.require_staff_session(text) from public;

create or replace function public.create_ticket(
  p_token text, p_transaction_ref text, p_bill_amount numeric,
  p_bank text, p_table_number text, p_tip_amount numeric default 0
) returns public.tickets
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; created public.tickets;
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
  insert into public.tickets(
    business_id,waiter_id,table_number,transaction_ref,bill_amount,tip_amount,bank,status
  ) values (
    s.business_id,s.staff_number,btrim(p_table_number),upper(btrim(p_transaction_ref)),
    p_bill_amount,greatest(coalesce(p_tip_amount,0),0),btrim(p_bank),'pending'
  ) returning * into created;
  return created;
end $$;

create or replace function public.list_tickets(p_token text, p_scope text default 'business')
returns setof public.tickets
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if p_scope='waiter' then
    return query select t.* from public.tickets t
      where t.business_id=s.business_id and t.waiter_id=s.staff_number
      order by t.created_at desc limit 100;
  end if;
  if s.role not in ('cashier','admin') then
    raise exception 'Role is not allowed to view the business ledger' using errcode='42501';
  end if;
  return query select t.* from public.tickets t
    where t.business_id=s.business_id order by t.created_at desc limit 100;
end $$;

create or replace function public.transition_ticket(
  p_token text, p_ticket_id uuid, p_status text,
  p_actual_amount numeric default null, p_tip_amount numeric default null
) returns public.tickets
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; changed public.tickets;
begin
  s:=public.require_staff_session(p_token);
  if s.role not in ('cashier','admin') then
    raise exception 'Role is not allowed to transition tickets' using errcode='42501';
  end if;
  if p_status not in ('settled','rejected') then
    raise exception 'Invalid ticket transition' using errcode='22023';
  end if;
  update public.tickets set
    status=p_status,
    actual_amount=case when p_status='settled' then p_actual_amount else actual_amount end,
    tip_amount=case when p_status='settled' then greatest(coalesce(p_tip_amount,0),0) else tip_amount end,
    updated_at=now()
  where ticket_id=p_ticket_id and business_id=s.business_id and status='pending'
  returning * into changed;
  if not found then
    raise exception 'Pending ticket not found' using errcode='P0002';
  end if;
  return changed;
end $$;

create or replace function public.logout_staff(p_token text)
returns void language plpgsql security definer set search_path=public,extensions as $$
begin
  update public.staff_sessions set revoked_at=now()
  where token_hash=extensions.digest(convert_to(p_token,'UTF8'),'sha256') and revoked_at is null;
end $$;

revoke all on function public.create_ticket(text,text,numeric,text,text,numeric) from public;
revoke all on function public.list_tickets(text,text) from public;
revoke all on function public.transition_ticket(text,uuid,text,numeric,numeric) from public;
revoke all on function public.logout_staff(text) from public;
grant execute on function public.create_ticket(text,text,numeric,text,text,numeric) to anon,authenticated;
grant execute on function public.list_tickets(text,text) to anon,authenticated;
grant execute on function public.transition_ticket(text,uuid,text,numeric,numeric) to anon,authenticated;
grant execute on function public.logout_staff(text) to anon,authenticated;

drop policy if exists tickets_insert_active_business on public.tickets;
drop policy if exists tickets_select_active_business on public.tickets;
drop policy if exists tickets_update_active_business on public.tickets;
revoke all on public.tickets from anon,authenticated;

-- Migration: 202608050001_waiter_wallet_history.sql
-- Waiter wallet totals and receipt history must include the staff member's
-- complete verified history. Keep the broader business ledger bounded.
create or replace function public.list_tickets(p_token text, p_scope text default 'business')
returns setof public.tickets
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if p_scope='waiter' then
    return query select t.* from public.tickets t
      where t.business_id=s.business_id and t.waiter_id=s.staff_number
      order by t.created_at desc;
  end if;
  if s.role not in ('cashier','admin') then
    raise exception 'Role is not allowed to view the business ledger' using errcode='42501';
  end if;
  return query select t.* from public.tickets t
    where t.business_id=s.business_id order by t.created_at desc limit 100;
end $$;

revoke all on function public.list_tickets(text,text) from public;
grant execute on function public.list_tickets(text,text) to anon,authenticated;

-- Migration: 202608050002_verification_attempts.sql
create table if not exists public.verification_attempts (
  attempt_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  staff_number text not null,
  provider text not null,
  transaction_ref text,
  expected_amount numeric,
  verified_amount numeric,
  tip_amount numeric not null default 0,
  outcome text not null check (outcome in ('verified','failed')),
  error_message text,
  created_at timestamptz not null default now()
);
create index if not exists verification_attempts_staff_created_idx
  on public.verification_attempts (business_id,staff_number,created_at desc);
alter table public.verification_attempts enable row level security;
revoke all on public.verification_attempts from anon,authenticated;

create or replace function public.record_verification_attempt(
  p_token text,p_provider text,p_transaction_ref text,p_expected_amount numeric,
  p_verified_amount numeric,p_tip_amount numeric,p_outcome text,p_error_message text default null
) returns public.verification_attempts
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; created public.verification_attempts;
begin
  s:=public.require_staff_session(p_token);
  if s.role not in ('waiter','admin') then
    raise exception 'Role is not allowed to verify receipts' using errcode='42501';
  end if;
  if p_outcome not in ('verified','failed') then
    raise exception 'Invalid verification outcome' using errcode='22023';
  end if;
  insert into public.verification_attempts(
    business_id,staff_number,provider,transaction_ref,expected_amount,
    verified_amount,tip_amount,outcome,error_message
  ) values (
    s.business_id,s.staff_number,lower(btrim(p_provider)),nullif(upper(btrim(p_transaction_ref)),''),
    p_expected_amount,p_verified_amount,greatest(coalesce(p_tip_amount,0),0),p_outcome,
    nullif(left(coalesce(p_error_message,''),500),'')
  ) returning * into created;
  return created;
end $$;

create or replace function public.list_my_verification_attempts(p_token text)
returns setof public.verification_attempts
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  return query select a.* from public.verification_attempts a
    where a.business_id=s.business_id and a.staff_number=s.staff_number
    order by a.created_at desc;
end $$;

revoke all on function public.record_verification_attempt(text,text,text,numeric,numeric,numeric,text,text) from public;
revoke all on function public.list_my_verification_attempts(text) from public;
grant execute on function public.record_verification_attempt(text,text,text,numeric,numeric,numeric,text,text) to anon,authenticated;
grant execute on function public.list_my_verification_attempts(text) to anon,authenticated;

-- Migration: 202608090001_admin_password_change.sql
-- Let a signed-in restaurant administrator rotate their own password without
-- exposing the staff table to the anonymous Supabase client.

create or replace function public.change_current_admin_password(
  p_token text,
  p_current_password text,
  p_new_password text
) returns void
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  s public.staff_sessions;
  current_staff public.staff;
begin
  s:=public.require_staff_session(p_token);

  select st.* into current_staff
  from public.staff st
  where st.business_id=s.business_id
    and st.staff_number=s.staff_number
    and st.is_active
  limit 1;

  if not found or s.role <> 'admin' or current_staff.role <> 'admin' then
    raise exception 'Only an administrator can change this password'
      using errcode='42501';
  end if;

  if p_current_password is null or not (
    (current_staff.password_hash is not null and
      extensions.crypt(p_current_password,current_staff.password_hash)=current_staff.password_hash)
    or
    (current_staff.password_hash is null and current_staff.password=p_current_password)
  ) then
    raise exception 'Current password is incorrect' using errcode='P0001';
  end if;

  if p_new_password is null or length(p_new_password) < 8 then
    raise exception 'New password must be at least 8 characters long'
      using errcode='22023';
  end if;

  if p_new_password=p_current_password then
    raise exception 'New password must be different from the current password'
      using errcode='22023';
  end if;

  -- The existing staff_hash_password trigger hashes this value and clears the
  -- legacy plaintext column before the row is written.
  update public.staff
  set password=p_new_password
  where business_id=s.business_id and staff_number=s.staff_number;

  -- Keep the session that authorized the rotation, but revoke every other
  -- session for this administrator so other devices must authenticate again.
  update public.staff_sessions
  set revoked_at=now()
  where business_id=s.business_id
    and staff_number=s.staff_number
    and session_id<>s.session_id
    and revoked_at is null;
end $$;

revoke all on function public.change_current_admin_password(text,text,text) from public;
grant execute on function public.change_current_admin_password(text,text,text) to anon,authenticated;

-- Migration: 202608110001_admin_filters_receipts_withdrawals.sql
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

-- Migration: 202608120001_atomic_server_verification.sql
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

-- Migration: 202608120002_auth_and_tenant_hardening.sql
-- Harden restaurant authentication and move tenant/staff administration behind
-- token-authenticated, role-checked functions. Platform administration is no
-- longer available through anonymous table reads or plaintext credentials.

alter table public.staff
  add column if not exists failed_login_attempts integer not null default 0,
  add column if not exists locked_until timestamptz,
  add column if not exists last_login_at timestamptz,
  add column if not exists password_changed_at timestamptz;

create table if not exists public.security_audit_log (
  audit_id bigint generated always as identity primary key,
  business_id uuid references public.businesses(business_id) on delete set null,
  actor_staff_number text,
  action text not null,
  subject_type text not null,
  subject_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists security_audit_business_created_idx
  on public.security_audit_log (business_id,created_at desc);
alter table public.security_audit_log enable row level security;
revoke all on public.security_audit_log from anon,authenticated;

create or replace function public.login_staff(
  p_business_id uuid,p_phone text,p_password text
) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare candidate public.staff; business public.businesses; raw_token text; failures integer;
begin
  select * into business from public.businesses b
  where b.business_id=p_business_id and b.is_active;
  if not found then return null; end if;

  select * into candidate from public.staff st
  where st.business_id=p_business_id and st.phone_number=btrim(p_phone)
  limit 1;
  if not found or not candidate.is_active then
    insert into public.security_audit_log(business_id,action,subject_type,subject_id,metadata)
    values(p_business_id,'login_failed','staff',btrim(p_phone),jsonb_build_object('reason','invalid_credentials'));
    return null;
  end if;

  if candidate.locked_until is not null and candidate.locked_until > now() then
    insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id,metadata)
    values(p_business_id,candidate.staff_number,'login_blocked','staff',candidate.staff_number,
      jsonb_build_object('locked_until',candidate.locked_until));
    return null;
  end if;

  if not (
    (candidate.password_hash is not null and
      extensions.crypt(p_password,candidate.password_hash)=candidate.password_hash)
    or (candidate.password_hash is null and candidate.password=p_password)
  ) then
    failures:=candidate.failed_login_attempts+1;
    update public.staff set
      failed_login_attempts=failures,
      locked_until=case when failures>=5 then now()+interval '15 minutes' else null end
    where business_id=p_business_id and staff_number=candidate.staff_number;
    insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id,metadata)
    values(p_business_id,candidate.staff_number,'login_failed','staff',candidate.staff_number,
      jsonb_build_object('attempt',failures,'locked',failures>=5));
    return null;
  end if;

  if candidate.password_hash is null then
    update public.staff set
      password_hash=extensions.crypt(p_password,extensions.gen_salt('bf')),password=null
    where business_id=p_business_id and staff_number=candidate.staff_number;
  end if;
  update public.staff set failed_login_attempts=0,locked_until=null,last_login_at=now()
  where business_id=p_business_id and staff_number=candidate.staff_number;
  raw_token:=encode(extensions.gen_random_bytes(32),'hex');
  insert into public.staff_sessions(token_hash,business_id,staff_number,role,expires_at)
  values(extensions.digest(convert_to(raw_token,'UTF8'),'sha256'),p_business_id,
    candidate.staff_number,candidate.role,now()+interval '12 hours');
  insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id)
  values(p_business_id,candidate.staff_number,'login_succeeded','session',candidate.staff_number);
  return jsonb_build_object(
    'token',raw_token,'business_id',p_business_id,'business_name',business.name,
    'staff_number',candidate.staff_number,'role',candidate.role,
    'max_staff_limit',business.max_staff_limit,
    'has_cashier_module',business.has_cashier_module,
    'expires_at',now()+interval '12 hours'
  );
end $$;

create or replace function public.lookup_business(p_code text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare b public.businesses;
begin
  select * into b from public.businesses
  where business_code=upper(btrim(p_code)) limit 1;
  if not found then return null; end if;
  return jsonb_build_object('business_id',b.business_id,'name',b.name,
    'business_code',b.business_code,'is_active',b.is_active);
end $$;

create or replace function public.get_current_business(p_token text) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; b public.businesses;
begin
  s:=public.require_staff_session(p_token);
  select * into b from public.businesses where business_id=s.business_id;
  return to_jsonb(b)-'created_by'-'internal_notes';
end $$;

create or replace function public.list_staff_roster(p_token text) returns table(
  staff_number text,name text,phone_number text,role text,is_active boolean,created_at timestamptz
)
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if s.role<>'admin' then raise exception 'Administrator role required' using errcode='42501'; end if;
  return query select st.staff_number,st.name,st.phone_number,st.role,st.is_active,st.created_at
    from public.staff st where st.business_id=s.business_id order by st.created_at desc;
end $$;

create or replace function public.update_bank_accounts(p_token text,p_accounts jsonb) returns void
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if s.role<>'admin' then raise exception 'Administrator role required' using errcode='42501'; end if;
  update public.businesses set bank_accounts=coalesce(p_accounts,'{}'::jsonb)
    where business_id=s.business_id;
  insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id)
  values(s.business_id,s.staff_number,'payment_accounts_updated','business',s.business_id::text);
end $$;

create or replace function public.create_staff_member(
  p_token text,p_staff_number text,p_name text,p_phone text,p_password text,p_role text
) returns void
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; b public.businesses; seat_count integer;
begin
  s:=public.require_staff_session(p_token);
  if s.role<>'admin' then raise exception 'Administrator role required' using errcode='42501'; end if;
  select * into b from public.businesses where business_id=s.business_id for update;
  if p_role not in ('waiter','cashier') then raise exception 'Invalid staff role' using errcode='22023'; end if;
  if p_role='cashier' and not b.has_cashier_module then
    raise exception 'Cashier module is not included in this plan' using errcode='42501';
  end if;
  select count(*) into seat_count from public.staff where business_id=s.business_id and is_active;
  if seat_count>=b.max_staff_limit then raise exception 'Staff limit reached' using errcode='23514'; end if;
  if length(coalesce(p_password,''))<8 then raise exception 'Password must be at least 8 characters' using errcode='22023'; end if;
  insert into public.staff(staff_number,business_id,name,phone_number,password,role,is_active)
  values(btrim(p_staff_number),s.business_id,btrim(p_name),btrim(p_phone),p_password,p_role,true);
  insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id,metadata)
  values(s.business_id,s.staff_number,'staff_created','staff',btrim(p_staff_number),jsonb_build_object('role',p_role));
end $$;

create or replace function public.update_staff_member(
  p_token text,p_staff_number text,p_name text,p_phone text,p_new_password text,p_role text
) returns void
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; b public.businesses;
begin
  s:=public.require_staff_session(p_token);
  if s.role<>'admin' then raise exception 'Administrator role required' using errcode='42501'; end if;
  if p_staff_number=s.staff_number then raise exception 'Use the password settings to update your own account' using errcode='42501'; end if;
  if p_role not in ('waiter','cashier') then raise exception 'Invalid staff role' using errcode='22023'; end if;
  select * into b from public.businesses where business_id=s.business_id;
  if p_role='cashier' and not b.has_cashier_module then raise exception 'Cashier module is not included in this plan' using errcode='42501'; end if;
  if nullif(p_new_password,'') is not null and length(p_new_password)<8 then
    raise exception 'Password must be at least 8 characters' using errcode='22023';
  end if;
  update public.staff set name=btrim(p_name),phone_number=btrim(p_phone),role=p_role,
    password=case when nullif(p_new_password,'') is null then password else p_new_password end
  where business_id=s.business_id and staff_number=p_staff_number;
  if not found then raise exception 'Staff member not found' using errcode='P0002'; end if;
  update public.staff_sessions set revoked_at=now()
    where business_id=s.business_id and staff_number=p_staff_number and revoked_at is null;
  insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id,metadata)
  values(s.business_id,s.staff_number,'staff_updated','staff',p_staff_number,jsonb_build_object('role',p_role));
end $$;

create or replace function public.set_staff_active(
  p_token text,p_staff_number text,p_active boolean
) returns void
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if s.role<>'admin' then raise exception 'Administrator role required' using errcode='42501'; end if;
  if p_staff_number=s.staff_number then raise exception 'You cannot deactivate your own account' using errcode='42501'; end if;
  update public.staff set is_active=p_active where business_id=s.business_id and staff_number=p_staff_number;
  if not found then raise exception 'Staff member not found' using errcode='P0002'; end if;
  if not p_active then update public.staff_sessions set revoked_at=now()
    where business_id=s.business_id and staff_number=p_staff_number and revoked_at is null; end if;
  insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id,metadata)
  values(s.business_id,s.staff_number,'staff_status_changed','staff',p_staff_number,jsonb_build_object('active',p_active));
end $$;

create or replace function public.list_my_sessions(p_token text) returns table(
  session_id uuid,created_at timestamptz,expires_at timestamptz,is_current boolean
) language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  return query select ss.session_id,ss.created_at,ss.expires_at,ss.session_id=s.session_id
  from public.staff_sessions ss where ss.business_id=s.business_id
    and ss.staff_number=s.staff_number and ss.revoked_at is null and ss.expires_at>now()
  order by ss.created_at desc;
end $$;

create or replace function public.revoke_staff_session(p_token text,p_session_id uuid) returns void
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  update public.staff_sessions set revoked_at=now()
  where session_id=p_session_id and business_id=s.business_id and staff_number=s.staff_number;
end $$;

revoke all on function public.lookup_business(text) from public;
grant execute on function public.lookup_business(text) to anon,authenticated;
revoke all on function public.get_current_business(text) from public;
revoke all on function public.list_staff_roster(text) from public;
revoke all on function public.update_bank_accounts(text,jsonb) from public;
revoke all on function public.create_staff_member(text,text,text,text,text,text) from public;
revoke all on function public.update_staff_member(text,text,text,text,text,text) from public;
revoke all on function public.set_staff_active(text,text,boolean) from public;
revoke all on function public.list_my_sessions(text) from public;
revoke all on function public.revoke_staff_session(text,uuid) from public;
grant execute on function public.get_current_business(text) to anon,authenticated;
grant execute on function public.list_staff_roster(text) to anon,authenticated;
grant execute on function public.update_bank_accounts(text,jsonb) to anon,authenticated;
grant execute on function public.create_staff_member(text,text,text,text,text,text) to anon,authenticated;
grant execute on function public.update_staff_member(text,text,text,text,text,text) to anon,authenticated;
grant execute on function public.set_staff_active(text,text,boolean) to anon,authenticated;
grant execute on function public.list_my_sessions(text) to anon,authenticated;
grant execute on function public.revoke_staff_session(text,uuid) to anon,authenticated;

-- Direct REST access exposed password and tenant administration fields. All
-- active Flutter restaurant flows now use the functions above.
revoke all on public.staff from anon,authenticated;
revoke all on public.businesses from anon,authenticated;
do $$ begin
  if to_regclass('public.super_admins') is not null then
    execute 'revoke all on public.super_admins from anon,authenticated';
  end if;
end $$;

-- Migration: 202608120003_immutable_financial_ledger.sql
-- Immutable verified values, auditable ticket transitions, tip payout ledger,
-- and unbounded server-side filtered reporting.

alter table public.tickets
  add column if not exists settled_by text,
  add column if not exists settled_at timestamptz,
  add column if not exists rejected_by text,
  add column if not exists rejected_at timestamptz,
  add column if not exists status_reason text,
  add column if not exists financial_state text not null default 'normal';

create table if not exists public.ticket_financial_events (
  event_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  ticket_id uuid not null references public.tickets(ticket_id) on delete cascade,
  actor_staff_number text not null,
  action text not null check (action in ('settled','rejected','voided','refunded','disputed')),
  previous_status text,
  new_status text,
  reason text not null check (length(btrim(reason)) between 3 and 500),
  amount numeric,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists ticket_financial_events_ticket_idx
  on public.ticket_financial_events (business_id,ticket_id,created_at desc);
alter table public.ticket_financial_events enable row level security;
revoke all on public.ticket_financial_events from anon,authenticated;

create or replace function public.prevent_financial_evidence_mutation() returns trigger
language plpgsql set search_path=public as $$
begin
  raise exception 'Financial evidence is immutable' using errcode='55000';
end $$;
drop trigger if exists payment_evidence_immutable on public.payment_verification_evidence;
create trigger payment_evidence_immutable before update or delete
  on public.payment_verification_evidence for each row
  execute function public.prevent_financial_evidence_mutation();
drop trigger if exists ticket_financial_events_immutable on public.ticket_financial_events;
create trigger ticket_financial_events_immutable before update or delete
  on public.ticket_financial_events for each row
  execute function public.prevent_financial_evidence_mutation();

create or replace function public.protect_verified_ticket_values() returns trigger
language plpgsql set search_path=public as $$
begin
  if old.verification_evidence_id is not null and (
    new.business_id is distinct from old.business_id or
    new.waiter_id is distinct from old.waiter_id or
    new.transaction_ref is distinct from old.transaction_ref or
    new.bank is distinct from old.bank or
    new.bill_amount is distinct from old.bill_amount or
    new.expected_amount is distinct from old.expected_amount or
    new.verified_amount is distinct from old.verified_amount or
    new.tip_amount is distinct from old.tip_amount or
    new.provider_transaction_at is distinct from old.provider_transaction_at or
    new.payer_name is distinct from old.payer_name or
    new.payer_account is distinct from old.payer_account or
    new.receiver_name is distinct from old.receiver_name or
    new.receiver_account is distinct from old.receiver_account or
    new.verification_evidence_id is distinct from old.verification_evidence_id
  ) then
    raise exception 'Verified payment values cannot be changed' using errcode='55000';
  end if;
  return new;
end $$;
drop trigger if exists tickets_protect_verified_values on public.tickets;
create trigger tickets_protect_verified_values before update on public.tickets
  for each row execute function public.protect_verified_ticket_values();

create or replace function public.transition_verified_ticket(
  p_token text,p_ticket_id uuid,p_status text,p_reason text
) returns public.tickets
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; current_ticket public.tickets; changed public.tickets; reason text;
begin
  s:=public.require_staff_session(p_token);
  if s.role not in ('cashier','admin') then
    raise exception 'Cashier or administrator role required' using errcode='42501';
  end if;
  if p_status not in ('settled','rejected') then
    raise exception 'Invalid ticket transition' using errcode='22023';
  end if;
  reason:=btrim(coalesce(p_reason,''));
  if length(reason)<3 then raise exception 'A reason is required' using errcode='22023'; end if;
  select * into current_ticket from public.tickets
    where ticket_id=p_ticket_id and business_id=s.business_id and status='pending'
    for update;
  if not found then raise exception 'Pending ticket not found' using errcode='P0002'; end if;
  if current_ticket.verification_evidence_id is null or current_ticket.verified_amount is null then
    raise exception 'Ticket has no authoritative verification evidence' using errcode='55000';
  end if;

  update public.tickets set
    status=p_status,
    actual_amount=case when p_status='settled' then verified_amount else actual_amount end,
    settled_by=case when p_status='settled' then s.staff_number else settled_by end,
    settled_at=case when p_status='settled' then now() else settled_at end,
    rejected_by=case when p_status='rejected' then s.staff_number else rejected_by end,
    rejected_at=case when p_status='rejected' then now() else rejected_at end,
    status_reason=reason,updated_at=now()
  where ticket_id=p_ticket_id returning * into changed;

  insert into public.ticket_financial_events(
    business_id,ticket_id,actor_staff_number,action,previous_status,new_status,reason,amount
  ) values (
    s.business_id,p_ticket_id,s.staff_number,p_status,current_ticket.status,p_status,reason,
    case when p_status='settled' then current_ticket.verified_amount else null end
  );
  return changed;
end $$;

create or replace function public.record_ticket_financial_action(
  p_token text,p_ticket_id uuid,p_action text,p_reason text
) returns void
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; ticket public.tickets; next_state text; reason text;
begin
  s:=public.require_staff_session(p_token);
  if s.role<>'admin' then raise exception 'Administrator role required' using errcode='42501'; end if;
  if p_action not in ('voided','refunded','disputed') then raise exception 'Invalid financial action' using errcode='22023'; end if;
  reason:=btrim(coalesce(p_reason,''));
  if length(reason)<3 then raise exception 'A reason is required' using errcode='22023'; end if;
  select * into ticket from public.tickets where ticket_id=p_ticket_id and business_id=s.business_id for update;
  if not found then raise exception 'Ticket not found' using errcode='P0002'; end if;
  next_state:=p_action;
  update public.tickets set financial_state=next_state,updated_at=now() where ticket_id=p_ticket_id;
  insert into public.ticket_financial_events(
    business_id,ticket_id,actor_staff_number,action,previous_status,new_status,reason,amount
  ) values (
    s.business_id,p_ticket_id,s.staff_number,p_action,ticket.financial_state,next_state,reason,
    ticket.verified_amount
  );
end $$;

create or replace function public.list_ticket_report(
  p_token text,p_from timestamptz default null,p_to timestamptz default null,
  p_staff_number text default null,p_provider text default null
) returns setof public.tickets
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if s.role not in ('cashier','admin') then raise exception 'Business ledger role required' using errcode='42501'; end if;
  return query select t.* from public.tickets t
  where t.business_id=s.business_id
    and (p_from is null or t.created_at>=p_from)
    and (p_to is null or t.created_at<p_to)
    and (nullif(btrim(p_staff_number),'') is null or t.waiter_id=p_staff_number)
    and (nullif(lower(btrim(p_provider)),'') is null or lower(t.bank)=lower(btrim(p_provider)))
  order by t.created_at desc;
end $$;

alter table public.tip_withdrawal_requests
  add column if not exists paid_at timestamptz,
  add column if not exists paid_by text;
alter table public.tip_withdrawal_requests
  drop constraint if exists tip_withdrawal_requests_status_check;
alter table public.tip_withdrawal_requests
  add constraint tip_withdrawal_requests_status_check
  check (status in ('pending','approved','rejected','paid'));

create table if not exists public.tip_payout_ledger (
  payout_event_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  request_id uuid not null references public.tip_withdrawal_requests(request_id) on delete restrict,
  staff_number text not null,
  actor_staff_number text not null,
  action text not null check (action in ('approved','rejected','paid')),
  amount numeric not null check (amount>0),
  created_at timestamptz not null default now()
);
alter table public.tip_payout_ledger enable row level security;
revoke all on public.tip_payout_ledger from anon,authenticated;
drop trigger if exists tip_payout_ledger_immutable on public.tip_payout_ledger;
create trigger tip_payout_ledger_immutable before update or delete on public.tip_payout_ledger
  for each row execute function public.prevent_financial_evidence_mutation();

create or replace function public.request_tip_withdrawal(p_token text,p_amount numeric)
returns public.tip_withdrawal_requests
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; earned numeric; committed numeric; created public.tip_withdrawal_requests;
begin
  s:=public.require_staff_session(p_token);
  if s.role<>'waiter' then raise exception 'Only waiters can request tip withdrawals' using errcode='42501'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Withdrawal amount must be positive' using errcode='22023'; end if;
  select coalesce(sum(t.tip_amount),0) into earned from public.tickets t
    where t.business_id=s.business_id and t.waiter_id=s.staff_number and t.status='settled';
  select coalesce(sum(w.amount),0) into committed from public.tip_withdrawal_requests w
    where w.business_id=s.business_id and w.staff_number=s.staff_number
      and w.status in ('pending','approved','paid');
  if p_amount>earned-committed then raise exception 'Withdrawal amount exceeds available tip balance' using errcode='22023'; end if;
  insert into public.tip_withdrawal_requests(business_id,staff_number,amount)
  values(s.business_id,s.staff_number,p_amount) returning * into created;
  return created;
end $$;

create or replace function public.resolve_tip_withdrawal_request(
  p_token text,p_request_id uuid,p_status text
) returns public.tip_withdrawal_requests
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; current_request public.tip_withdrawal_requests; changed public.tip_withdrawal_requests;
begin
  s:=public.require_staff_session(p_token);
  if s.role<>'admin' then raise exception 'Only an administrator can resolve withdrawals' using errcode='42501'; end if;
  select * into current_request from public.tip_withdrawal_requests
    where request_id=p_request_id and business_id=s.business_id for update;
  if not found then raise exception 'Withdrawal request not found' using errcode='P0002'; end if;
  if not ((current_request.status='pending' and p_status in ('approved','rejected')) or
          (current_request.status='approved' and p_status='paid')) then
    raise exception 'Invalid withdrawal transition' using errcode='22023';
  end if;
  update public.tip_withdrawal_requests set status=p_status,
    resolved_at=case when p_status in ('approved','rejected') then now() else resolved_at end,
    resolved_by=case when p_status in ('approved','rejected') then s.staff_number else resolved_by end,
    paid_at=case when p_status='paid' then now() else paid_at end,
    paid_by=case when p_status='paid' then s.staff_number else paid_by end
  where request_id=p_request_id returning * into changed;
  insert into public.tip_payout_ledger(business_id,request_id,staff_number,actor_staff_number,action,amount)
  values(s.business_id,p_request_id,current_request.staff_number,s.staff_number,p_status,current_request.amount);
  return changed;
end $$;

revoke all on function public.transition_ticket(text,uuid,text,numeric,numeric) from public,anon,authenticated;
revoke all on function public.transition_verified_ticket(text,uuid,text,text) from public;
revoke all on function public.record_ticket_financial_action(text,uuid,text,text) from public;
revoke all on function public.list_ticket_report(text,timestamptz,timestamptz,text,text) from public;
grant execute on function public.transition_verified_ticket(text,uuid,text,text) to anon,authenticated;
grant execute on function public.record_ticket_financial_action(text,uuid,text,text) to anon,authenticated;
grant execute on function public.list_ticket_report(text,timestamptz,timestamptz,text,text) to anon,authenticated;

-- Migration: 202608120004_subscription_lifecycle.sql
-- Subscription lifecycle for a controlled pilot. Billing mutations are
-- service-role only; entitlements are enforced for every active app session.

alter table public.businesses
  add column if not exists subscription_status text not null default 'active',
  add column if not exists subscription_started_at timestamptz not null default now(),
  add column if not exists subscription_ends_at timestamptz,
  add column if not exists grace_ends_at timestamptz,
  add column if not exists cancelled_at timestamptz;

alter table public.businesses
  drop constraint if exists businesses_subscription_status_check;
alter table public.businesses add constraint businesses_subscription_status_check
  check (subscription_status in ('trial','active','overdue','grace_period','cancelled','suspended'));

create table if not exists public.subscription_invoices (
  invoice_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  invoice_number text not null unique,
  plan_tier text not null,
  amount numeric not null check (amount>=0),
  currency text not null default 'ETB',
  status text not null default 'open' check (status in ('draft','open','paid','void','uncollectible')),
  period_start timestamptz not null,
  period_end timestamptz not null,
  due_at timestamptz not null,
  paid_at timestamptz,
  external_reference text,
  created_at timestamptz not null default now()
);
create index if not exists subscription_invoices_business_idx
  on public.subscription_invoices(business_id,created_at desc);
alter table public.subscription_invoices enable row level security;
revoke all on public.subscription_invoices from anon,authenticated;

create table if not exists public.subscription_payments (
  payment_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  invoice_id uuid references public.subscription_invoices(invoice_id) on delete set null,
  amount numeric not null check (amount>0),
  currency text not null default 'ETB',
  payment_method text not null,
  external_reference text unique,
  received_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
alter table public.subscription_payments enable row level security;
revoke all on public.subscription_payments from anon,authenticated;

create or replace function public.subscription_has_access(b public.businesses) returns boolean
language sql stable set search_path=public as $$
  select b.is_active and (
    b.subscription_status in ('trial','active') or
    (b.subscription_status in ('overdue','grace_period') and b.grace_ends_at is not null and b.grace_ends_at>now())
  ) and (b.subscription_ends_at is null or b.subscription_ends_at>now() or
    (b.grace_ends_at is not null and b.grace_ends_at>now()));
$$;

-- Re-issue login with the lockout/audit behavior from the previous migration
-- plus subscription access enforcement.
create or replace function public.login_staff(
  p_business_id uuid,p_phone text,p_password text
) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare candidate public.staff; business public.businesses; raw_token text; failures integer;
begin
  select * into business from public.businesses b
  where b.business_id=p_business_id and public.subscription_has_access(b);
  if not found then return null; end if;
  select * into candidate from public.staff st
  where st.business_id=p_business_id and st.phone_number=btrim(p_phone) limit 1 for update;
  if not found or not candidate.is_active then
    insert into public.security_audit_log(business_id,action,subject_type,subject_id,metadata)
    values(p_business_id,'login_failed','staff',btrim(p_phone),jsonb_build_object('reason','invalid_credentials'));
    return null;
  end if;
  if candidate.locked_until is not null and candidate.locked_until>now() then
    insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id,metadata)
    values(p_business_id,candidate.staff_number,'login_blocked','staff',candidate.staff_number,
      jsonb_build_object('locked_until',candidate.locked_until));
    return null;
  end if;
  if not ((candidate.password_hash is not null and
      extensions.crypt(p_password,candidate.password_hash)=candidate.password_hash)
    or (candidate.password_hash is null and candidate.password=p_password)) then
    failures:=candidate.failed_login_attempts+1;
    update public.staff set failed_login_attempts=failures,
      locked_until=case when failures>=5 then now()+interval '15 minutes' else null end
    where business_id=p_business_id and staff_number=candidate.staff_number;
    insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id,metadata)
    values(p_business_id,candidate.staff_number,'login_failed','staff',candidate.staff_number,
      jsonb_build_object('attempt',failures,'locked',failures>=5));
    return null;
  end if;
  if candidate.password_hash is null then
    update public.staff set password_hash=extensions.crypt(p_password,extensions.gen_salt('bf')),password=null
    where business_id=p_business_id and staff_number=candidate.staff_number;
  end if;
  update public.staff set failed_login_attempts=0,locked_until=null,last_login_at=now()
  where business_id=p_business_id and staff_number=candidate.staff_number;
  raw_token:=encode(extensions.gen_random_bytes(32),'hex');
  insert into public.staff_sessions(token_hash,business_id,staff_number,role,expires_at)
  values(extensions.digest(convert_to(raw_token,'UTF8'),'sha256'),p_business_id,
    candidate.staff_number,candidate.role,now()+interval '12 hours');
  insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id)
  values(p_business_id,candidate.staff_number,'login_succeeded','session',candidate.staff_number);
  return jsonb_build_object(
    'token',raw_token,'business_id',p_business_id,'business_name',business.name,
    'staff_number',candidate.staff_number,'role',candidate.role,
    'max_staff_limit',business.max_staff_limit,'has_cashier_module',business.has_cashier_module,
    'subscription_status',business.subscription_status,'subscription_ends_at',business.subscription_ends_at,
    'expires_at',now()+interval '12 hours'
  );
end $$;

create or replace function public.require_staff_session(p_token text)
returns public.staff_sessions
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  if p_token is null or length(p_token)<32 then
    raise exception 'Invalid or expired staff session' using errcode='28000';
  end if;
  select ss.* into s from public.staff_sessions ss
  join public.businesses b on b.business_id=ss.business_id
  join public.staff st on st.business_id=ss.business_id and st.staff_number=ss.staff_number
  where ss.token_hash=extensions.digest(convert_to(p_token,'UTF8'),'sha256')
    and ss.revoked_at is null and ss.expires_at>now() and st.is_active
    and public.subscription_has_access(b);
  if not found then raise exception 'Session expired or subscription unavailable' using errcode='28000'; end if;
  return s;
end $$;
revoke all on function public.require_staff_session(text) from public;

create or replace function public.get_subscription_summary(p_token text) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; b public.businesses;
begin
  s:=public.require_staff_session(p_token);
  select * into b from public.businesses where business_id=s.business_id;
  return jsonb_build_object(
    'tier',b.subscription_tier,'status',b.subscription_status,
    'started_at',b.subscription_started_at,'ends_at',b.subscription_ends_at,
    'grace_ends_at',b.grace_ends_at,'max_staff',b.max_staff_limit,
    'has_cashier',b.has_cashier_module
  );
end $$;

create or replace function public.list_subscription_history(p_token text) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if s.role<>'admin' then raise exception 'Administrator role required' using errcode='42501'; end if;
  return jsonb_build_object(
    'invoices',coalesce((select jsonb_agg(to_jsonb(i) order by i.created_at desc)
      from public.subscription_invoices i where i.business_id=s.business_id),'[]'::jsonb),
    'payments',coalesce((select jsonb_agg(to_jsonb(p) order by p.received_at desc)
      from public.subscription_payments p where p.business_id=s.business_id),'[]'::jsonb)
  );
end $$;

create or replace function public.service_update_subscription(
  p_business_id uuid,p_tier text,p_status text,p_started_at timestamptz,
  p_ends_at timestamptz,p_grace_ends_at timestamptz,p_max_staff integer,p_has_cashier boolean
) returns void
language plpgsql security definer set search_path=public as $$
begin
  if p_status not in ('trial','active','overdue','grace_period','cancelled','suspended') then
    raise exception 'Invalid subscription status' using errcode='22023';
  end if;
  if p_max_staff<1 then raise exception 'Staff entitlement must be positive' using errcode='22023'; end if;
  update public.businesses set subscription_tier=p_tier,subscription_status=p_status,
    subscription_started_at=p_started_at,subscription_ends_at=p_ends_at,
    grace_ends_at=p_grace_ends_at,max_staff_limit=p_max_staff,
    has_cashier_module=p_has_cashier,
    cancelled_at=case when p_status='cancelled' then now() else null end
  where business_id=p_business_id;
  if not found then raise exception 'Business not found' using errcode='P0002'; end if;
  if p_status in ('cancelled','suspended') then
    update public.staff_sessions set revoked_at=now() where business_id=p_business_id and revoked_at is null;
  end if;
end $$;

create or replace function public.service_create_subscription_invoice(
  p_business_id uuid,p_invoice_number text,p_plan_tier text,p_amount numeric,
  p_currency text,p_period_start timestamptz,p_period_end timestamptz,p_due_at timestamptz
) returns public.subscription_invoices
language plpgsql security definer set search_path=public as $$
declare created public.subscription_invoices;
begin
  insert into public.subscription_invoices(
    business_id,invoice_number,plan_tier,amount,currency,period_start,period_end,due_at
  ) values (
    p_business_id,upper(btrim(p_invoice_number)),btrim(p_plan_tier),p_amount,
    upper(coalesce(nullif(btrim(p_currency),''),'ETB')),p_period_start,p_period_end,p_due_at
  ) returning * into created;
  return created;
end $$;

create or replace function public.service_record_subscription_payment(
  p_invoice_id uuid,p_amount numeric,p_method text,p_reference text,p_metadata jsonb
) returns public.subscription_payments
language plpgsql security definer set search_path=public as $$
declare invoice public.subscription_invoices; created public.subscription_payments;
begin
  select * into invoice from public.subscription_invoices where invoice_id=p_invoice_id for update;
  if not found then raise exception 'Invoice not found' using errcode='P0002'; end if;
  if invoice.status<>'open' then raise exception 'Invoice is not open' using errcode='22023'; end if;
  if p_amount<invoice.amount then raise exception 'Payment does not cover invoice amount' using errcode='22023'; end if;
  insert into public.subscription_payments(
    business_id,invoice_id,amount,currency,payment_method,external_reference,metadata
  ) values (
    invoice.business_id,p_invoice_id,p_amount,invoice.currency,btrim(p_method),
    nullif(btrim(p_reference),''),coalesce(p_metadata,'{}'::jsonb)
  ) returning * into created;
  update public.subscription_invoices set status='paid',paid_at=now(),
    external_reference=created.external_reference where invoice_id=p_invoice_id;
  update public.businesses set subscription_status='active',subscription_tier=invoice.plan_tier,
    subscription_started_at=invoice.period_start,subscription_ends_at=invoice.period_end,
    grace_ends_at=null,cancelled_at=null where business_id=invoice.business_id;
  return created;
end $$;

create or replace function public.service_refresh_subscription_statuses() returns integer
language plpgsql security definer set search_path=public as $$
declare changed integer:=0; count_step integer;
begin
  update public.businesses set subscription_status='overdue',
    grace_ends_at=coalesce(grace_ends_at,now()+interval '7 days')
  where subscription_status in ('trial','active') and subscription_ends_at<=now();
  get diagnostics count_step=row_count; changed:=changed+count_step;
  update public.businesses set subscription_status='suspended'
  where subscription_status in ('overdue','grace_period') and grace_ends_at<=now();
  get diagnostics count_step=row_count; changed:=changed+count_step;
  update public.staff_sessions ss set revoked_at=now()
  where ss.revoked_at is null and exists (
    select 1 from public.businesses b where b.business_id=ss.business_id
      and b.subscription_status in ('cancelled','suspended')
  );
  return changed;
end $$;

revoke all on function public.get_subscription_summary(text) from public;
revoke all on function public.list_subscription_history(text) from public;
grant execute on function public.get_subscription_summary(text) to anon,authenticated;
grant execute on function public.list_subscription_history(text) to anon,authenticated;
revoke all on function public.service_update_subscription(uuid,text,text,timestamptz,timestamptz,timestamptz,integer,boolean)
  from public,anon,authenticated;
grant execute on function public.service_update_subscription(uuid,text,text,timestamptz,timestamptz,timestamptz,integer,boolean)
  to service_role;
revoke all on function public.service_create_subscription_invoice(uuid,text,text,numeric,text,timestamptz,timestamptz,timestamptz)
  from public,anon,authenticated;
grant execute on function public.service_create_subscription_invoice(uuid,text,text,numeric,text,timestamptz,timestamptz,timestamptz)
  to service_role;
revoke all on function public.service_record_subscription_payment(uuid,numeric,text,text,jsonb)
  from public,anon,authenticated;
grant execute on function public.service_record_subscription_payment(uuid,numeric,text,text,jsonb)
  to service_role;
revoke all on function public.service_refresh_subscription_statuses() from public,anon,authenticated;
grant execute on function public.service_refresh_subscription_statuses() to service_role;

-- Migration: 202608120005_privacy_support_compliance.sql
-- Versioned legal consent, support cases, retention configuration, and
-- account-deletion requests. Destructive erasure is intentionally processed
-- by an audited operator workflow after statutory retention review.

create table if not exists public.legal_documents (
  document_type text not null check (document_type in ('privacy','terms')),
  version text not null,
  effective_at timestamptz not null,
  url text not null,
  is_current boolean not null default false,
  primary key(document_type,version)
);
alter table public.legal_documents enable row level security;
grant select on public.legal_documents to anon,authenticated;

create table if not exists public.staff_consents (
  consent_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  staff_number text not null,
  document_type text not null,
  document_version text not null,
  accepted_at timestamptz not null default now(),
  unique(business_id,staff_number,document_type,document_version),
  foreign key(document_type,document_version)
    references public.legal_documents(document_type,version)
);
alter table public.staff_consents enable row level security;
revoke all on public.staff_consents from anon,authenticated;

create table if not exists public.business_data_retention (
  business_id uuid primary key references public.businesses(business_id) on delete cascade,
  receipt_retention_days integer not null default 365 check (receipt_retention_days between 30 and 3650),
  financial_retention_days integer not null default 2555 check (financial_retention_days between 365 and 3650),
  updated_at timestamptz not null default now(),
  updated_by text
);
alter table public.business_data_retention enable row level security;
revoke all on public.business_data_retention from anon,authenticated;

create table if not exists public.support_cases (
  case_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid references public.businesses(business_id) on delete set null,
  opened_by text not null,
  category text not null check (category in ('billing','payment','account','privacy','technical','other')),
  subject text not null check (length(btrim(subject)) between 3 and 120),
  description text not null check (length(btrim(description)) between 10 and 2000),
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  status text not null default 'open' check (status in ('open','in_progress','resolved','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.support_cases enable row level security;
revoke all on public.support_cases from anon,authenticated;

create table if not exists public.account_deletion_requests (
  request_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete restrict,
  requested_by text not null,
  reason text,
  status text not null default 'pending_review'
    check (status in ('pending_review','retention_hold','approved','completed','rejected')),
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by text,
  review_notes text
);
alter table public.account_deletion_requests enable row level security;
revoke all on public.account_deletion_requests from anon,authenticated;

create or replace function public.accept_legal_document(
  p_token text,p_document_type text,p_version text
) returns void
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if not exists(select 1 from public.legal_documents d where d.document_type=p_document_type and d.version=p_version and d.is_current) then
    raise exception 'Legal document version is not current' using errcode='22023';
  end if;
  insert into public.staff_consents(business_id,staff_number,document_type,document_version)
  values(s.business_id,s.staff_number,p_document_type,p_version) on conflict do nothing;
end $$;

create or replace function public.open_support_case(
  p_token text,p_category text,p_subject text,p_description text,p_priority text default 'normal'
) returns public.support_cases
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; created public.support_cases;
begin
  s:=public.require_staff_session(p_token);
  insert into public.support_cases(business_id,opened_by,category,subject,description,priority)
  values(s.business_id,s.staff_number,p_category,btrim(p_subject),btrim(p_description),p_priority)
  returning * into created;
  return created;
end $$;

create or replace function public.list_my_support_cases(p_token text)
returns setof public.support_cases
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  return query select c.* from public.support_cases c where c.business_id=s.business_id
    and (s.role='admin' or c.opened_by=s.staff_number) order by c.created_at desc;
end $$;

create or replace function public.request_business_deletion(p_token text,p_reason text)
returns public.account_deletion_requests
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; created public.account_deletion_requests;
begin
  s:=public.require_staff_session(p_token);
  if s.role<>'admin' then raise exception 'Administrator role required' using errcode='42501'; end if;
  if exists(select 1 from public.account_deletion_requests r where r.business_id=s.business_id and r.status in ('pending_review','retention_hold','approved')) then
    raise exception 'A deletion request is already active' using errcode='23505';
  end if;
  insert into public.account_deletion_requests(business_id,requested_by,reason)
  values(s.business_id,s.staff_number,nullif(btrim(p_reason),'')) returning * into created;
  insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id)
  values(s.business_id,s.staff_number,'account_deletion_requested','business',s.business_id::text);
  return created;
end $$;

revoke all on function public.accept_legal_document(text,text,text) from public;
revoke all on function public.open_support_case(text,text,text,text,text) from public;
revoke all on function public.list_my_support_cases(text) from public;
revoke all on function public.request_business_deletion(text,text) from public;
grant execute on function public.accept_legal_document(text,text,text) to anon,authenticated;
grant execute on function public.open_support_case(text,text,text,text,text) to anon,authenticated;
grant execute on function public.list_my_support_cases(text) to anon,authenticated;
grant execute on function public.request_business_deletion(text,text) to anon,authenticated;

insert into public.legal_documents(document_type,version,effective_at,url,is_current)
values
  ('privacy','2026-08-12',now(),'https://YOUR_DOMAIN/privacy',true),
  ('terms','2026-08-12',now(),'https://YOUR_DOMAIN/terms',true)
on conflict(document_type,version) do nothing;

-- Migration: 202608170001_payment_correctness.sql
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

-- Migration: 202608220001_operator_console.sql
-- Server-only platform operator console. Credentials and MFA are verified by
-- the TypeScript API; these functions remain service-role only and every
-- privileged mutation writes an immutable operator audit entry.

create table if not exists public.operator_audit_log (
  audit_id bigint generated always as identity primary key,
  operator_email text not null,
  action text not null,
  subject_type text not null,
  subject_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists operator_audit_created_idx
  on public.operator_audit_log(created_at desc);
alter table public.operator_audit_log enable row level security;
revoke all on public.operator_audit_log from public,anon,authenticated;

create or replace function public.service_operator_record_audit(
  p_operator_email text,p_action text,p_subject_type text,p_subject_id text,p_metadata jsonb default '{}'::jsonb
) returns void
language plpgsql security definer set search_path=public as $$
begin
  insert into public.operator_audit_log(operator_email,action,subject_type,subject_id,metadata)
  values(lower(btrim(p_operator_email)),btrim(p_action),btrim(p_subject_type),nullif(btrim(p_subject_id),''),coalesce(p_metadata,'{}'::jsonb));
end $$;

create or replace function public.service_operator_snapshot() returns jsonb
language plpgsql security definer set search_path=public as $$
begin
  return jsonb_build_object(
    'metrics',jsonb_build_object(
      'businesses',(select count(*) from public.businesses),
      'active_businesses',(select count(*) from public.businesses where is_active and subscription_status not in ('suspended','cancelled')),
      'attention_businesses',(select count(*) from public.businesses where not is_active or subscription_status in ('overdue','grace_period','suspended','cancelled')),
      'active_sessions',(select count(*) from public.staff_sessions where revoked_at is null and expires_at>now()),
      'open_support_cases',(select count(*) from public.support_cases where status in ('open','in_progress')),
      'open_invoices',(select count(*) from public.subscription_invoices where status='open')
    ),
    'businesses',coalesce((
      select jsonb_agg(jsonb_build_object(
        'business_id',b.business_id,'name',b.name,'business_code',b.business_code,'address',b.address,
        'subscription_tier',b.subscription_tier,'subscription_status',b.subscription_status,
        'subscription_started_at',b.subscription_started_at,'subscription_ends_at',b.subscription_ends_at,
        'grace_ends_at',b.grace_ends_at,'max_staff_limit',b.max_staff_limit,
        'has_cashier_module',b.has_cashier_module,'is_active',b.is_active,'created_at',b.created_at,
        'staff_count',(select count(*) from public.staff st where st.business_id=b.business_id),
        'active_staff_count',(select count(*) from public.staff st where st.business_id=b.business_id and st.is_active),
        'active_sessions',(select count(*) from public.staff_sessions ss where ss.business_id=b.business_id and ss.revoked_at is null and ss.expires_at>now()),
        'ticket_count',(select count(*) from public.tickets t where t.business_id=b.business_id)
      ) order by b.created_at desc) from public.businesses b
    ),'[]'::jsonb),
    'support_cases',coalesce((
      select jsonb_agg(jsonb_build_object(
        'case_id',c.case_id,'business_id',c.business_id,'business_name',b.name,'opened_by',c.opened_by,
        'category',c.category,'subject',c.subject,'description',c.description,'priority',c.priority,
        'status',c.status,'created_at',c.created_at,'updated_at',c.updated_at
      ) order by c.created_at desc)
      from public.support_cases c left join public.businesses b on b.business_id=c.business_id
    ),'[]'::jsonb),
    'deletion_requests',coalesce((
      select jsonb_agg(jsonb_build_object(
        'request_id',r.request_id,'business_id',r.business_id,'business_name',b.name,
        'requested_by',r.requested_by,'reason',r.reason,'status',r.status,'requested_at',r.requested_at,
        'reviewed_at',r.reviewed_at,'reviewed_by',r.reviewed_by,'review_notes',r.review_notes
      ) order by r.requested_at desc)
      from public.account_deletion_requests r join public.businesses b on b.business_id=r.business_id
    ),'[]'::jsonb),
    'invoices',coalesce((
      select jsonb_agg(jsonb_build_object(
        'invoice_id',i.invoice_id,'business_id',i.business_id,'business_name',b.name,
        'invoice_number',i.invoice_number,'plan_tier',i.plan_tier,'amount',i.amount,'currency',i.currency,
        'status',i.status,'period_start',i.period_start,'period_end',i.period_end,
        'due_at',i.due_at,'paid_at',i.paid_at,'created_at',i.created_at
      ) order by i.created_at desc)
      from public.subscription_invoices i join public.businesses b on b.business_id=i.business_id
    ),'[]'::jsonb),
    'operator_audit',coalesce((
      select jsonb_agg(to_jsonb(a) order by a.created_at desc)
      from (select * from public.operator_audit_log order by created_at desc limit 100) a
    ),'[]'::jsonb)
  );
end $$;

create or replace function public.service_operator_create_business(
  p_operator_email text,p_name text,p_business_code text,p_address text,p_tier text,p_status text,
  p_max_staff integer,p_has_cashier boolean,p_admin_name text,p_admin_phone text,p_admin_password text,p_admin_pin text
) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare created public.businesses;
begin
  if length(btrim(p_name))<2 then raise exception 'Restaurant name is required' using errcode='22023'; end if;
  if upper(btrim(p_business_code))!~'^[A-Z0-9-]{3,32}$' then raise exception 'Invalid workspace code' using errcode='22023'; end if;
  if p_tier not in ('starter','basic','pro') then raise exception 'Invalid subscription tier' using errcode='22023'; end if;
  if p_status not in ('trial','active','overdue','grace_period','cancelled','suspended') then raise exception 'Invalid subscription status' using errcode='22023'; end if;
  if p_max_staff<1 then raise exception 'Staff limit must be positive' using errcode='22023'; end if;
  if length(coalesce(p_admin_password,''))<10 then raise exception 'Root-admin password must be at least 10 characters' using errcode='22023'; end if;
  insert into public.businesses(
    name,business_code,address,subscription_tier,subscription_status,subscription_started_at,
    subscription_ends_at,max_staff_limit,has_cashier_module,is_active
  ) values (
    btrim(p_name),upper(btrim(p_business_code)),nullif(btrim(p_address),''),p_tier,p_status,now(),
    case when p_status='trial' then now()+interval '14 days' else null end,
    p_max_staff,p_has_cashier,p_status not in ('cancelled','suspended')
  ) returning * into created;
  insert into public.staff(staff_number,business_id,name,phone_number,password,role,is_active)
  values(btrim(p_admin_pin),created.business_id,btrim(p_admin_name),btrim(p_admin_phone),p_admin_password,'admin',true);
  perform public.service_operator_record_audit(
    p_operator_email,'business_created','business',created.business_id::text,
    jsonb_build_object('name',created.name,'business_code',created.business_code,'tier',p_tier,'root_admin',btrim(p_admin_pin))
  );
  return jsonb_build_object('business_id',created.business_id,'name',created.name,'business_code',created.business_code);
end $$;

create or replace function public.service_operator_set_business_active(
  p_operator_email text,p_business_id uuid,p_active boolean,p_reason text default null
) returns void
language plpgsql security definer set search_path=public as $$
begin
  update public.businesses set is_active=p_active where business_id=p_business_id;
  if not found then raise exception 'Business not found' using errcode='P0002'; end if;
  if not p_active then
    update public.staff_sessions set revoked_at=now()
    where business_id=p_business_id and revoked_at is null;
  end if;
  perform public.service_operator_record_audit(
    p_operator_email,'business_status_changed','business',p_business_id::text,
    jsonb_build_object('active',p_active,'reason',nullif(btrim(p_reason),''))
  );
end $$;

create or replace function public.service_operator_update_subscription(
  p_operator_email text,p_business_id uuid,p_tier text,p_status text,p_ends_at timestamptz,
  p_grace_ends_at timestamptz,p_max_staff integer,p_has_cashier boolean
) returns void
language plpgsql security definer set search_path=public as $$
begin
  if p_tier not in ('starter','basic','pro') then raise exception 'Invalid subscription tier' using errcode='22023'; end if;
  if p_status not in ('trial','active','overdue','grace_period','cancelled','suspended') then raise exception 'Invalid subscription status' using errcode='22023'; end if;
  if p_max_staff<1 then raise exception 'Staff limit must be positive' using errcode='22023'; end if;
  update public.businesses set
    subscription_tier=p_tier,subscription_status=p_status,subscription_ends_at=p_ends_at,
    grace_ends_at=p_grace_ends_at,max_staff_limit=p_max_staff,has_cashier_module=p_has_cashier,
    is_active=p_status not in ('cancelled','suspended'),
    cancelled_at=case when p_status='cancelled' then now() else null end
  where business_id=p_business_id;
  if not found then raise exception 'Business not found' using errcode='P0002'; end if;
  if p_status in ('cancelled','suspended') then
    update public.staff_sessions set revoked_at=now()
    where business_id=p_business_id and revoked_at is null;
  end if;
  perform public.service_operator_record_audit(
    p_operator_email,'subscription_updated','business',p_business_id::text,
    jsonb_build_object('tier',p_tier,'status',p_status,'max_staff',p_max_staff,'has_cashier',p_has_cashier)
  );
end $$;

create or replace function public.service_operator_revoke_business_sessions(
  p_operator_email text,p_business_id uuid,p_reason text default null
) returns integer
language plpgsql security definer set search_path=public as $$
declare changed integer;
begin
  update public.staff_sessions set revoked_at=now()
  where business_id=p_business_id and revoked_at is null and expires_at>now();
  get diagnostics changed=row_count;
  perform public.service_operator_record_audit(
    p_operator_email,'business_sessions_revoked','business',p_business_id::text,
    jsonb_build_object('revoked',changed,'reason',nullif(btrim(p_reason),''))
  );
  return changed;
end $$;

create or replace function public.service_operator_update_support_case(
  p_operator_email text,p_case_id uuid,p_status text
) returns void
language plpgsql security definer set search_path=public as $$
begin
  if p_status not in ('open','in_progress','resolved','closed') then raise exception 'Invalid support status' using errcode='22023'; end if;
  update public.support_cases set status=p_status,updated_at=now() where case_id=p_case_id;
  if not found then raise exception 'Support case not found' using errcode='P0002'; end if;
  perform public.service_operator_record_audit(
    p_operator_email,'support_case_updated','support_case',p_case_id::text,jsonb_build_object('status',p_status)
  );
end $$;

create or replace function public.service_operator_review_deletion(
  p_operator_email text,p_request_id uuid,p_status text,p_notes text default null
) returns void
language plpgsql security definer set search_path=public as $$
begin
  if p_status not in ('pending_review','retention_hold','approved','rejected') then
    raise exception 'Completion requires the separate audited retention job' using errcode='22023';
  end if;
  update public.account_deletion_requests set
    status=p_status,reviewed_at=now(),reviewed_by=lower(btrim(p_operator_email)),review_notes=nullif(btrim(p_notes),'')
  where request_id=p_request_id;
  if not found then raise exception 'Deletion request not found' using errcode='P0002'; end if;
  perform public.service_operator_record_audit(
    p_operator_email,'deletion_request_reviewed','deletion_request',p_request_id::text,jsonb_build_object('status',p_status)
  );
end $$;

revoke all on function public.service_operator_record_audit(text,text,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.service_operator_snapshot() from public,anon,authenticated;
revoke all on function public.service_operator_create_business(text,text,text,text,text,text,integer,boolean,text,text,text,text) from public,anon,authenticated;
revoke all on function public.service_operator_set_business_active(text,uuid,boolean,text) from public,anon,authenticated;
revoke all on function public.service_operator_update_subscription(text,uuid,text,text,timestamptz,timestamptz,integer,boolean) from public,anon,authenticated;
revoke all on function public.service_operator_revoke_business_sessions(text,uuid,text) from public,anon,authenticated;
revoke all on function public.service_operator_update_support_case(text,uuid,text) from public,anon,authenticated;
revoke all on function public.service_operator_review_deletion(text,uuid,text,text) from public,anon,authenticated;
grant execute on function public.service_operator_record_audit(text,text,text,text,jsonb) to service_role;
grant execute on function public.service_operator_snapshot() to service_role;
grant execute on function public.service_operator_create_business(text,text,text,text,text,text,integer,boolean,text,text,text,text) to service_role;
grant execute on function public.service_operator_set_business_active(text,uuid,boolean,text) to service_role;
grant execute on function public.service_operator_update_subscription(text,uuid,text,text,timestamptz,timestamptz,integer,boolean) to service_role;
grant execute on function public.service_operator_revoke_business_sessions(text,uuid,text) to service_role;
grant execute on function public.service_operator_update_support_case(text,uuid,text) to service_role;
grant execute on function public.service_operator_review_deletion(text,uuid,text,text) to service_role;

-- Migration: 202608260001_complete_schema_security.sql
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

-- Migration: 202608260002_legacy_staff_compatibility.sql
-- Schema marker for the legacy-staff compatibility bootstrap. The actual
-- normalization runs in base_schema.sql before functions and constraints are
-- installed, allowing the one-shot bundle to upgrade the original pilot.

insert into public.chekmi_schema_meta(singleton,schema_version,applied_at)
values(true,'2026-08-26.2',now())
on conflict(singleton) do update set
  schema_version=excluded.schema_version,
  applied_at=excluded.applied_at;

notify pgrst,'reload schema';

-- Migration: 202608260003_missing_staff_phone_quarantine.sql
-- The original pilot allowed staff without phone numbers, while current
-- authentication requires a tenant-scoped phone. Preserve those rows but keep
-- their generated placeholders from becoming active login identifiers.

update public.staff
set is_active=false
where phone_number like 'legacy-unset-%';

insert into public.chekmi_schema_meta(singleton,schema_version,applied_at)
values(true,'2026-08-26.3',now())
on conflict(singleton) do update set
  schema_version=excluded.schema_version,
  applied_at=excluded.applied_at;

notify pgrst,'reload schema';

commit;

select schema_version,applied_at
from public.chekmi_schema_meta
where singleton=true;

select count(*) as legacy_staff_requiring_phone_update
from public.staff
where phone_number like 'legacy-unset-%';
