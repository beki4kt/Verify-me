-- Read-only assertions for a migrated, explicitly seeded CHEKMI staging database.
-- psql must run this file with ON_ERROR_STOP enabled.

do $$
declare
  demo_business public.businesses;
  active_demo_staff integer;
begin
  select * into demo_business
  from public.businesses
  where business_code='MESOB-DEMO';

  if not found then
    raise exception 'Staging seed is missing MESOB-DEMO';
  end if;
  if not demo_business.is_active or not demo_business.has_cashier_module then
    raise exception 'MESOB-DEMO is not active with the cashier module enabled';
  end if;

  select count(*) into active_demo_staff
  from public.staff
  where business_id=demo_business.business_id
    and phone_number in ('+251911000001','+251911000002','+251911000003')
    and role in ('admin','cashier','waiter')
    and is_active
    and password is null
    and password_hash is not null;

  if active_demo_staff<>3 then
    raise exception 'Expected three active, password-hashed demo staff accounts; found %',active_demo_staff;
  end if;

  if to_regprocedure('public.lookup_business(text)') is null or
     to_regprocedure('public.login_staff(uuid,text,text)') is null or
     to_regprocedure('public.list_tickets(text,text)') is null or
     to_regprocedure('public.get_verification_context(text,text)') is null or
     to_regprocedure('public.commit_verified_payment(text,text,text,text,numeric,numeric,text,text,text,text,text,timestamptz,text,jsonb,text)') is null or
     to_regprocedure('public.transition_verified_ticket(text,uuid,text,text)') is null or
     to_regprocedure('public.service_operator_snapshot()') is null then
    raise exception 'One or more required CHEKMI RPC functions are missing';
  end if;
end $$;

select
  b.business_code,
  b.subscription_tier,
  b.subscription_status,
  b.is_active,
  count(distinct s.staff_number) filter (where s.is_active) as active_staff,
  count(distinct ss.session_id) filter (
    where ss.revoked_at is null and ss.expires_at>now()
  ) as active_sessions
from public.businesses b
left join public.staff s on s.business_id=b.business_id
left join public.staff_sessions ss on ss.business_id=b.business_id
where b.business_code='MESOB-DEMO'
group by b.business_id,b.business_code,b.subscription_tier,b.subscription_status,b.is_active;
