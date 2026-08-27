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
