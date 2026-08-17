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
