-- Additive workspace evolution. Existing businesses keep their restaurant flow;
-- new businesses receive neutral defaults. No historical evidence is rewritten.
create table if not exists public.workspace_profiles (
  business_id uuid primary key references public.businesses(business_id) on delete cascade,
  use_case text not null default 'general'
    check (use_case in ('general','personal','shop','restaurant','service')),
  default_reference_kind text not null default 'none'
    check (default_reference_kind in ('none','invoice','order','booking','customer','table','note')),
  review_policy text not null default 'automatic'
    check (review_policy in ('automatic','review_required')),
  tips_enabled boolean not null default false,
  overpayment_policy text not null default 'unresolved'
    check (overpayment_policy in ('unresolved','legacy_tip')),
  updated_at timestamptz not null default now(),
  constraint legacy_tip_restaurant_only check
    (overpayment_policy <> 'legacy_tip' or use_case = 'restaurant'),
  constraint tips_policy_enabled check
    (overpayment_policy <> 'legacy_tip' or tips_enabled)
);
alter table public.workspace_profiles enable row level security;
revoke all on public.workspace_profiles from public, anon, authenticated;

insert into public.workspace_profiles
  (business_id,use_case,default_reference_kind,review_policy,tips_enabled,overpayment_policy)
select business_id,'restaurant','table','review_required',true,'legacy_tip'
from public.businesses
on conflict (business_id) do nothing;

create or replace function public.create_workspace_profile() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  insert into public.workspace_profiles(business_id) values (new.business_id)
  on conflict (business_id) do nothing;
  return new;
end $$;

-- New tips are deliberate, immutable allocations against unresolved excess.
-- Historical ticket.tip_amount remains unchanged for old restaurant payouts.
alter table public.tickets
  add column if not exists allocated_tip_amount numeric not null default 0;
create table if not exists public.payment_tip_allocations (
  allocation_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  ticket_id uuid not null unique references public.tickets(ticket_id) on delete cascade,
  recipient_staff_number text not null,
  allocated_by text not null,
  amount numeric not null check (amount > 0),
  reason text not null check (length(btrim(reason)) between 3 and 500),
  created_at timestamptz not null default now()
);
alter table public.payment_tip_allocations enable row level security;
revoke all on public.payment_tip_allocations from public,anon,authenticated;
drop trigger if exists payment_tip_allocations_immutable on public.payment_tip_allocations;
create trigger payment_tip_allocations_immutable before update or delete
on public.payment_tip_allocations for each row
execute function public.prevent_financial_evidence_mutation();

drop trigger if exists businesses_create_workspace_profile on public.businesses;
create trigger businesses_create_workspace_profile after insert on public.businesses
for each row execute function public.create_workspace_profile();
revoke all on function public.create_workspace_profile() from public,anon,authenticated;

-- Explicit grants override legacy role presets; neither industry nor UI role
-- is trusted as authorization. The owning tenant is always part of the key.
create table if not exists public.workspace_member_capabilities (
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  staff_number text not null,
  capability text not null check (capability in
    ('verify_payment','review_payment','view_ledger','manage_members',
     'manage_receiving_accounts','manage_workspace','manage_tips')),
  allowed boolean not null,
  primary key (business_id,staff_number,capability),
  foreign key (business_id,staff_number)
    references public.staff(business_id,staff_number) on delete cascade
);
alter table public.workspace_member_capabilities enable row level security;
revoke all on public.workspace_member_capabilities from public,anon,authenticated;

create or replace function public.staff_can(
  p_business_id uuid,p_staff_number text,p_capability text
) returns boolean language plpgsql stable security definer set search_path=public as $$
declare explicit_grant boolean; member_role text;
begin
  if p_capability not in
    ('verify_payment','review_payment','view_ledger','manage_members',
     'manage_receiving_accounts','manage_workspace','manage_tips') then
    return false;
  end if;
  select st.role into member_role from public.staff st
  where st.business_id=p_business_id and st.staff_number=p_staff_number and st.is_active;
  if member_role is null then return false; end if;
  select mc.allowed into explicit_grant from public.workspace_member_capabilities mc
  where mc.business_id=p_business_id and mc.staff_number=p_staff_number
    and mc.capability=p_capability;
  if found then return explicit_grant; end if;
  return case member_role
    when 'admin' then true
    when 'waiter' then p_capability = 'verify_payment'
    when 'cashier' then p_capability in ('review_payment','view_ledger')
    else false end;
end $$;
revoke all on function public.staff_can(uuid,text,text) from public,anon,authenticated;
grant execute on function public.staff_can(uuid,text,text) to service_role;

-- Presets create explicit grants once. Later changing the display use case
-- never silently changes an existing member's effective permissions.
create or replace function public.apply_cashier_verify_preset() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if new.role='cashier' and exists(select 1 from public.workspace_profiles wp
      where wp.business_id=new.business_id and wp.use_case<>'restaurant') then
    insert into public.workspace_member_capabilities
      (business_id,staff_number,capability,allowed)
    values(new.business_id,new.staff_number,'verify_payment',true)
    on conflict (business_id,staff_number,capability) do nothing;
  end if;
  return new;
end $$;
drop trigger if exists staff_apply_cashier_verify_preset on public.staff;
create trigger staff_apply_cashier_verify_preset after insert or update of role on public.staff
for each row execute function public.apply_cashier_verify_preset();
revoke all on function public.apply_cashier_verify_preset() from public,anon,authenticated;

create or replace function public.get_workspace_profile(p_token text) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; profile public.workspace_profiles;
begin
  s:=public.require_staff_session(p_token);
  select * into profile from public.workspace_profiles where business_id=s.business_id;
  return jsonb_build_object(
    'use_case',profile.use_case,'default_reference_kind',profile.default_reference_kind,
    'review_policy',profile.review_policy,'tips_enabled',profile.tips_enabled,
    'overpayment_policy',profile.overpayment_policy,
    'capabilities',jsonb_build_object(
      'verify_payment',public.staff_can(s.business_id,s.staff_number,'verify_payment'),
      'review_payment',public.staff_can(s.business_id,s.staff_number,'review_payment'),
      'view_ledger',public.staff_can(s.business_id,s.staff_number,'view_ledger'),
      'manage_members',public.staff_can(s.business_id,s.staff_number,'manage_members'),
      'manage_receiving_accounts',public.staff_can(s.business_id,s.staff_number,'manage_receiving_accounts'),
      'manage_workspace',public.staff_can(s.business_id,s.staff_number,'manage_workspace'),
      'manage_tips',public.staff_can(s.business_id,s.staff_number,'manage_tips')));
end $$;

create or replace function public.update_workspace_profile(
  p_token text,p_use_case text,p_default_reference_kind text,
  p_review_policy text,p_tips_enabled boolean,p_overpayment_policy text
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; old_profile public.workspace_profiles;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'manage_workspace') then
    raise exception 'Workspace settings permission required' using errcode='42501';
  end if;
  select * into old_profile from public.workspace_profiles
  where business_id=s.business_id for update;
  if p_use_case not in ('general','personal','shop','restaurant','service') or
     p_default_reference_kind not in ('none','invoice','order','booking','customer','table','note') or
     p_review_policy not in ('automatic','review_required') or
     (p_overpayment_policy <> 'unresolved' and
       not (p_overpayment_policy='legacy_tip' and
         old_profile.overpayment_policy='legacy_tip' and
         p_use_case='restaurant' and p_tips_enabled)) or
     p_tips_enabled is null then
    raise exception 'Invalid workspace configuration' using errcode='22023';
  end if;
  update public.workspace_profiles set
    use_case=p_use_case,default_reference_kind=p_default_reference_kind,
    review_policy=p_review_policy,tips_enabled=p_tips_enabled,
    overpayment_policy=p_overpayment_policy,updated_at=now()
  where business_id=s.business_id;
  if p_use_case<>'restaurant' then
    insert into public.workspace_member_capabilities
      (business_id,staff_number,capability,allowed)
    select st.business_id,st.staff_number,'verify_payment',true
    from public.staff st where st.business_id=s.business_id and st.role='cashier'
    on conflict (business_id,staff_number,capability) do nothing;
  end if;
  insert into public.security_audit_log
    (business_id,actor_staff_number,action,subject_type,subject_id,metadata)
  values (s.business_id,s.staff_number,'workspace_profile_updated','business',
    s.business_id::text,jsonb_build_object('before',to_jsonb(old_profile),
    'after',jsonb_build_object('use_case',p_use_case,
      'default_reference_kind',p_default_reference_kind,
      'review_policy',p_review_policy,'tips_enabled',p_tips_enabled,
      'overpayment_policy',p_overpayment_policy)));
  return public.get_workspace_profile(p_token);
end $$;

create or replace function public.set_member_capability(
  p_token text,p_staff_number text,p_capability text,p_allowed boolean
) returns void language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'manage_members') then
    raise exception 'Member management permission required' using errcode='42501';
  end if;
  if p_staff_number=s.staff_number then
    raise exception 'You cannot change your own permissions' using errcode='42501';
  end if;
  if p_capability not in
    ('verify_payment','review_payment','view_ledger','manage_members',
     'manage_receiving_accounts','manage_workspace','manage_tips') or
     p_allowed is null then
    raise exception 'Invalid capability change' using errcode='22023';
  end if;
  if not exists(select 1 from public.staff where business_id=s.business_id
    and staff_number=p_staff_number and is_active) then
    raise exception 'Member not found' using errcode='P0002';
  end if;
  if exists(select 1 from public.staff where business_id=s.business_id
    and staff_number=p_staff_number and role='admin') then
    raise exception 'Owner permissions cannot be changed here' using errcode='42501';
  end if;
  insert into public.workspace_member_capabilities
    (business_id,staff_number,capability,allowed)
  values (s.business_id,p_staff_number,p_capability,p_allowed)
  on conflict (business_id,staff_number,capability)
  do update set allowed=excluded.allowed;
  insert into public.security_audit_log
    (business_id,actor_staff_number,action,subject_type,subject_id,metadata)
  values (s.business_id,s.staff_number,'member_capability_changed','staff',
    p_staff_number,jsonb_build_object('capability',p_capability,'allowed',p_allowed));
end $$;

revoke all on function public.get_workspace_profile(text) from public;
revoke all on function public.update_workspace_profile(text,text,text,text,boolean,text) from public;
revoke all on function public.set_member_capability(text,text,text,boolean) from public;
grant execute on function public.get_workspace_profile(text) to anon,authenticated;
grant execute on function public.update_workspace_profile(text,text,text,text,boolean,text) to anon,authenticated;
grant execute on function public.set_member_capability(text,text,text,boolean) to anon,authenticated;

-- Typed references and excess are projections of immutable verification facts.
alter table public.tickets
  add column if not exists reference_kind text,
  add column if not exists reference_value text,
  add column if not exists verified_by text,
  add column if not exists unresolved_excess numeric not null default 0;
alter table public.payment_verification_evidence
  add column if not exists reference_kind text,
  add column if not exists reference_value text,
  add column if not exists unresolved_excess numeric not null default 0;
alter table public.tickets add constraint tickets_unresolved_excess_nonnegative
  check (unresolved_excess >= 0);
alter table public.payment_verification_evidence add constraint evidence_unresolved_excess_nonnegative
  check (unresolved_excess >= 0);

create or replace function public.get_verification_context(
  p_token text,p_provider text
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; accounts jsonb; provider_key text; account_value text;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'verify_payment') then
    raise exception 'Payment verification permission required' using errcode='42501';
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
    else null end;
  if nullif(btrim(coalesce(account_value,'')),'') is null then
    raise exception 'This payment method is not configured for the workspace'
      using errcode='22023';
  end if;
  return jsonb_build_object('business_id',s.business_id,
    'staff_number',s.staff_number,'role',s.role,
    'provider',provider_key,'receiving_account',account_value);
end $$;

create or replace function public.list_tickets(p_token text,p_scope text default 'business')
returns setof public.tickets language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if p_scope='waiter' then
    return query select t.* from public.tickets t
      where t.business_id=s.business_id and t.waiter_id=s.staff_number
      order by t.created_at desc;
  end if;
  if p_scope <> 'business' or
     not (public.staff_can(s.business_id,s.staff_number,'view_ledger') or
          public.staff_can(s.business_id,s.staff_number,'review_payment')) then
    raise exception 'Ledger permission required' using errcode='42501';
  end if;
  return query select t.* from public.tickets t
    where t.business_id=s.business_id order by t.created_at desc limit 100;
end $$;

create or replace function public.update_bank_accounts(p_token text,p_accounts jsonb)
returns void language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'manage_receiving_accounts') then
    raise exception 'Receiving account management permission required' using errcode='42501';
  end if;
  if p_accounts is null or jsonb_typeof(p_accounts)<>'object' or
    exists(select 1 from jsonb_object_keys(p_accounts) as k(key)
      where k.key not in ('telebirr_number','cbe_number','cbebirr_number',
        'dashen_number','abyssinia_number','mpesa_number')) then
    raise exception 'Invalid receiving accounts' using errcode='22023';
  end if;
  update public.businesses set bank_accounts=p_accounts
  where business_id=s.business_id;
  insert into public.security_audit_log
    (business_id,actor_staff_number,action,subject_type,subject_id)
  values(s.business_id,s.staff_number,'payment_accounts_updated','business',
    s.business_id::text);
end $$;

create or replace function public.list_staff_roster(p_token text) returns table(
  staff_number text,name text,phone_number text,role text,
  is_active boolean,created_at timestamptz
) language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'manage_members') then
    raise exception 'Member management permission required' using errcode='42501';
  end if;
  return query select st.staff_number,st.name,st.phone_number,st.role,
    st.is_active,st.created_at from public.staff st
    where st.business_id=s.business_id order by st.created_at desc;
end $$;

create or replace function public.create_staff_member(
  p_token text,p_staff_number text,p_name text,p_phone text,p_password text,p_role text
) returns void language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; b public.businesses; profile public.workspace_profiles;
  seat_count integer;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'manage_members') then
    raise exception 'Member management permission required' using errcode='42501';
  end if;
  select * into b from public.businesses where business_id=s.business_id for update;
  select * into profile from public.workspace_profiles where business_id=s.business_id;
  if p_role not in ('waiter','cashier') then
    raise exception 'Invalid member preset' using errcode='22023';
  end if;
  if p_role='cashier' and profile.use_case='restaurant' and not b.has_cashier_module then
    raise exception 'Cashier module is not included in this plan' using errcode='42501';
  end if;
  select count(*) into seat_count from public.staff
  where business_id=s.business_id and is_active;
  if seat_count>=b.max_staff_limit then
    raise exception 'Staff limit reached' using errcode='23514';
  end if;
  if length(coalesce(p_password,''))<8 then
    raise exception 'Password must be at least 8 characters' using errcode='22023';
  end if;
  insert into public.staff(staff_number,business_id,name,phone_number,password,role,is_active)
  values(btrim(p_staff_number),s.business_id,btrim(p_name),btrim(p_phone),p_password,p_role,true);
  insert into public.security_audit_log
    (business_id,actor_staff_number,action,subject_type,subject_id,metadata)
  values(s.business_id,s.staff_number,'staff_created','staff',btrim(p_staff_number),
    jsonb_build_object('role',p_role));
end $$;

create or replace function public.update_staff_member(
  p_token text,p_staff_number text,p_name text,p_phone text,p_new_password text,p_role text
) returns void language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; b public.businesses; profile public.workspace_profiles;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'manage_members') then
    raise exception 'Member management permission required' using errcode='42501';
  end if;
  if p_staff_number=s.staff_number then
    raise exception 'You cannot change your own member preset' using errcode='42501';
  end if;
  if exists(select 1 from public.staff where business_id=s.business_id
    and staff_number=p_staff_number and role='admin') then
    raise exception 'Owner account cannot be changed here' using errcode='42501';
  end if;
  if p_role not in ('waiter','cashier') then
    raise exception 'Invalid member preset' using errcode='22023';
  end if;
  select * into b from public.businesses where business_id=s.business_id;
  select * into profile from public.workspace_profiles where business_id=s.business_id;
  if p_role='cashier' and profile.use_case='restaurant' and not b.has_cashier_module then
    raise exception 'Cashier module is not included in this plan' using errcode='42501';
  end if;
  if nullif(p_new_password,'') is not null and length(p_new_password)<8 then
    raise exception 'Password must be at least 8 characters' using errcode='22023';
  end if;
  update public.staff set name=btrim(p_name),phone_number=btrim(p_phone),role=p_role,
    password=case when nullif(p_new_password,'') is null then password else p_new_password end
  where business_id=s.business_id and staff_number=p_staff_number;
  if not found then raise exception 'Member not found' using errcode='P0002'; end if;
  update public.staff_sessions set revoked_at=now()
    where business_id=s.business_id and staff_number=p_staff_number and revoked_at is null;
  insert into public.security_audit_log
    (business_id,actor_staff_number,action,subject_type,subject_id,metadata)
  values(s.business_id,s.staff_number,'staff_updated','staff',p_staff_number,
    jsonb_build_object('role',p_role));
end $$;

create or replace function public.set_staff_active(
  p_token text,p_staff_number text,p_active boolean
) returns void language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'manage_members') then
    raise exception 'Member management permission required' using errcode='42501';
  end if;
  if p_staff_number=s.staff_number then
    raise exception 'You cannot deactivate your own account' using errcode='42501';
  end if;
  if exists(select 1 from public.staff where business_id=s.business_id
    and staff_number=p_staff_number and role='admin') then
    raise exception 'Owner account cannot be deactivated here' using errcode='42501';
  end if;
  update public.staff set is_active=p_active
  where business_id=s.business_id and staff_number=p_staff_number;
  if not found then raise exception 'Member not found' using errcode='P0002'; end if;
  if not p_active then
    update public.staff_sessions set revoked_at=now()
      where business_id=s.business_id and staff_number=p_staff_number and revoked_at is null;
  end if;
  insert into public.security_audit_log
    (business_id,actor_staff_number,action,subject_type,subject_id,metadata)
  values(s.business_id,s.staff_number,'staff_status_changed','staff',p_staff_number,
    jsonb_build_object('active',p_active));
end $$;

create or replace function public.list_workspace_members(p_token text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; result jsonb;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'manage_members') then
    raise exception 'Member management permission required' using errcode='42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'staff_number',st.staff_number,'name',st.name,'role',st.role,
    'is_active',st.is_active,
    'capabilities',jsonb_build_object(
      'verify_payment',public.staff_can(st.business_id,st.staff_number,'verify_payment'),
      'review_payment',public.staff_can(st.business_id,st.staff_number,'review_payment'),
      'view_ledger',public.staff_can(st.business_id,st.staff_number,'view_ledger'),
      'manage_receiving_accounts',public.staff_can(st.business_id,st.staff_number,'manage_receiving_accounts'),
      'manage_members',public.staff_can(st.business_id,st.staff_number,'manage_members'),
      'manage_workspace',public.staff_can(st.business_id,st.staff_number,'manage_workspace'),
      'manage_tips',public.staff_can(st.business_id,st.staff_number,'manage_tips')))
    order by st.created_at), '[]'::jsonb) into result
  from public.staff st where st.business_id=s.business_id;
  return result;
end $$;
revoke all on function public.list_workspace_members(text) from public;
grant execute on function public.list_workspace_members(text) to anon,authenticated;

create or replace function public.transition_verified_ticket(
  p_token text,p_ticket_id uuid,p_status text,p_reason text
) returns public.tickets language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; current_ticket public.tickets; changed public.tickets; reason text;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'review_payment') then
    raise exception 'Payment review permission required' using errcode='42501';
  end if;
  if p_status not in ('settled','rejected') then
    raise exception 'Invalid payment transition' using errcode='22023';
  end if;
  reason:=btrim(coalesce(p_reason,''));
  if length(reason)<3 then raise exception 'A reason is required' using errcode='22023'; end if;
  select * into current_ticket from public.tickets
    where ticket_id=p_ticket_id and business_id=s.business_id and status='pending' for update;
  if not found then raise exception 'Pending payment not found' using errcode='P0002'; end if;
  if current_ticket.verification_evidence_id is null or current_ticket.verified_amount is null then
    raise exception 'Payment has no authoritative verification evidence' using errcode='55000';
  end if;
  update public.tickets set status=p_status,
    actual_amount=case when p_status='settled' then verified_amount else actual_amount end,
    settled_by=case when p_status='settled' then s.staff_number else settled_by end,
    settled_at=case when p_status='settled' then now() else settled_at end,
    rejected_by=case when p_status='rejected' then s.staff_number else rejected_by end,
    rejected_at=case when p_status='rejected' then now() else rejected_at end,
    status_reason=reason,updated_at=now()
  where ticket_id=p_ticket_id returning * into changed;
  insert into public.ticket_financial_events
    (business_id,ticket_id,actor_staff_number,action,previous_status,new_status,reason,amount)
  values (s.business_id,p_ticket_id,s.staff_number,p_status,current_ticket.status,
    p_status,reason,case when p_status='settled' then current_ticket.verified_amount else null end);
  return changed;
end $$;

create or replace function public.list_ticket_report(
  p_token text,p_from timestamptz default null,p_to timestamptz default null,
  p_staff_number text default null,p_provider text default null
) returns setof public.tickets language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'view_ledger') then
    raise exception 'Ledger permission required' using errcode='42501';
  end if;
  return query select t.* from public.tickets t
  where t.business_id=s.business_id
    and (p_from is null or t.created_at>=p_from)
    and (p_to is null or t.created_at<p_to)
    and (nullif(btrim(p_staff_number),'') is null or t.waiter_id=p_staff_number)
    and (nullif(lower(btrim(p_provider)),'') is null or lower(t.bank)=lower(btrim(p_provider)))
  order by t.created_at desc;
end $$;

create or replace function public.commit_verified_payment(
  p_token text,p_provider text,p_transaction_ref text,p_table_number text,
  p_expected_amount numeric,p_verified_amount numeric,p_currency text,
  p_receiver_account text,p_receiver_name text,p_payer_account text,p_payer_name text,
  p_provider_transaction_at timestamptz,p_provider_status text,p_provider_payload jsonb,
  p_receipt_image_base64 text
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare
  s public.staff_sessions;
  profile public.workspace_profiles;
  evidence public.payment_verification_evidence;
  created public.tickets;
  receipt_bytes bytea;
  normalized_provider text;
  normalized_ref text;
  encoded_reference text;
  reference_kind text;
  reference_value text;
  excess numeric;
  tip numeric := 0;
  unresolved numeric := 0;
  completed boolean;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'verify_payment') then
    raise exception 'Payment verification permission required' using errcode='42501';
  end if;
  select * into profile from public.workspace_profiles
  where business_id=s.business_id;
  if not found then raise exception 'Workspace configuration missing' using errcode='55000'; end if;
  normalized_provider:=lower(regexp_replace(coalesce(p_provider,''),'[^a-z0-9]','','g'));
  if normalized_provider not in ('telebirr','cbe','cbebirr','dashen','abyssinia','mpesa') then
    raise exception 'Unsupported payment provider' using errcode='22023';
  end if;
  normalized_ref:=upper(btrim(coalesce(p_transaction_ref,'')));
  if normalized_ref='' then
    raise exception 'Transaction reference is required' using errcode='22023';
  end if;
  if p_expected_amount is null or p_expected_amount <= 0 or
     p_verified_amount is null or p_verified_amount < p_expected_amount then
    raise exception 'Verified payment amount is invalid' using errcode='22023';
  end if;
  if btrim(coalesce(p_receiver_account,''))='' then
    raise exception 'Verified receiver account is required' using errcode='22023';
  end if;

  -- The legacy wire field is retained until every Edge deployment uses typed
  -- parameters. A missing context is a real 'none', not a fabricated table.
  encoded_reference:=btrim(coalesce(p_table_number,''));
  if encoded_reference='' then
    encoded_reference:='Payment: '||normalized_ref;
  end if;
  reference_kind:=case
    when encoded_reference ~* '^Invoice: ' then 'invoice'
    when encoded_reference ~* '^Order: ' then 'order'
    when encoded_reference ~* '^Booking: ' then 'booking'
    when encoded_reference ~* '^Customer: ' then 'customer'
    when encoded_reference ~* '^Table: ' then 'table'
    when encoded_reference ~* '^(Note|Other): ' then 'note'
    when encoded_reference ~* '^Payment: ' then 'none'
    else 'table' end;
  reference_value:=case when reference_kind='none' then null
    when position(': ' in encoded_reference)>0 then
      nullif(btrim(split_part(encoded_reference,': ',2)),'')
    else nullif(encoded_reference,'') end;

  excess:=p_verified_amount-p_expected_amount;
  if profile.overpayment_policy='legacy_tip' and profile.tips_enabled then
    tip:=excess;
  else
    unresolved:=excess;
  end if;
  completed:=profile.review_policy='automatic';

  if nullif(btrim(coalesce(p_receipt_image_base64,'')),'') is not null then
    begin
      receipt_bytes:=decode(p_receipt_image_base64,'base64');
    exception when others then
      raise exception 'Receipt image is not valid base64' using errcode='22023';
    end;
    if octet_length(receipt_bytes)>1500000 then
      raise exception 'Compressed receipt image exceeds 1.5 MB' using errcode='22023';
    end if;
  end if;

  insert into public.payment_verification_evidence(
    business_id,staff_number,provider,transaction_ref,expected_amount,verified_amount,
    tip_amount,currency,receiver_account,receiver_name,payer_account,payer_name,
    provider_transaction_at,provider_status,provider_payload,
    reference_kind,reference_value,unresolved_excess
  ) values (
    s.business_id,s.staff_number,normalized_provider,normalized_ref,p_expected_amount,
    p_verified_amount,tip,coalesce(nullif(btrim(p_currency),''),'ETB'),
    btrim(p_receiver_account),nullif(btrim(coalesce(p_receiver_name,'')),''),
    nullif(btrim(coalesce(p_payer_account,'')),''),nullif(btrim(coalesce(p_payer_name,'')),''),
    p_provider_transaction_at,nullif(btrim(coalesce(p_provider_status,'')),''),
    coalesce(p_provider_payload,'{}'::jsonb),reference_kind,reference_value,unresolved
  ) returning * into evidence;

  insert into public.tickets(
    business_id,waiter_id,table_number,transaction_ref,bill_amount,expected_amount,
    verified_amount,tip_amount,bank,status,receipt_image_saved,
    provider_transaction_at,payer_name,payer_account,receiver_name,receiver_account,
    verification_evidence_id,reference_kind,reference_value,verified_by,unresolved_excess,
    actual_amount,settled_by,settled_at,status_reason
  ) values (
    s.business_id,s.staff_number,encoded_reference,normalized_ref,p_expected_amount,
    p_expected_amount,p_verified_amount,tip,normalized_provider,'pending',
    receipt_bytes is not null,p_provider_transaction_at,p_payer_name,p_payer_account,
    p_receiver_name,p_receiver_account,evidence.evidence_id,reference_kind,
    reference_value,s.staff_number,unresolved,null,null,null,null
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
  if completed then
    update public.tickets set status='settled',actual_amount=p_verified_amount,
      settled_by=s.staff_number,settled_at=now(),
      status_reason='Automatic workspace completion',updated_at=now()
    where ticket_id=created.ticket_id and business_id=s.business_id
    returning * into created;
    insert into public.ticket_financial_events(
      business_id,ticket_id,actor_staff_number,action,previous_status,
      new_status,reason,amount,metadata
    ) values (
      s.business_id,created.ticket_id,s.staff_number,'settled','pending',
      'settled','Automatic workspace completion',p_verified_amount,
      jsonb_build_object('completion_policy','automatic','verification_evidence_id',evidence.evidence_id)
    );
  end if;
  return jsonb_build_object(
    'ticket_id',created.ticket_id,'evidence_id',evidence.evidence_id,
    'provider',normalized_provider,'reference',normalized_ref,
    'reference_kind',reference_kind,'reference_value',reference_value,
    'expected_amount',p_expected_amount,'verified_amount',p_verified_amount,
    'tip_amount',tip,'unresolved_excess',unresolved,
    'status',created.status,'completion_status',
      case when completed then 'marked_complete' else 'requires_review' end,
    'receipt_saved',receipt_bytes is not null
  );
exception when unique_violation then
  raise exception 'This payment reference was already verified' using errcode='23505';
end $$;

-- The live Edge bundle uses the returned money fields. The migration is safe
-- with older bundles; rollout must deploy the matching Edge code before
-- enabling generic workspaces.

create or replace function public.find_committed_payment(
  p_token text,p_provider text,p_transaction_ref text
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; provider_key text; reference_key text; result jsonb;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'verify_payment') then
    raise exception 'Payment verification permission required' using errcode='42501';
  end if;
  provider_key:=lower(regexp_replace(coalesce(p_provider,''),'[^a-z0-9]','','g'));
  reference_key:=upper(btrim(coalesce(p_transaction_ref,'')));
  if provider_key not in ('telebirr','cbe','cbebirr','dashen','abyssinia','mpesa') or
     reference_key='' then
    raise exception 'Provider and transaction reference are required' using errcode='22023';
  end if;
  select jsonb_build_object(
    'ticket_id',t.ticket_id,'evidence_id',e.evidence_id,
    'provider',e.provider,'reference',e.transaction_ref,
    'reference_kind',t.reference_kind,'reference_value',t.reference_value,
    'expected_amount',e.expected_amount,'verified_amount',e.verified_amount,
    'tip_amount',e.tip_amount,'unresolved_excess',e.unresolved_excess,
    'status',t.status,'completion_status',
      case when t.status='settled' then 'marked_complete' else 'requires_review' end,
    'currency',e.currency,'receipt_saved',t.receipt_image_saved,
    'provider_transaction_at',e.provider_transaction_at,'created_at',e.created_at
  ) into result
  from public.payment_verification_evidence e
  join public.tickets t on t.verification_evidence_id=e.evidence_id
  where e.business_id=s.business_id and e.provider=provider_key
    and (e.transaction_ref=reference_key or
      upper(coalesce(e.provider_payload#>>'{verificationRequest,submittedReference}',''))=reference_key)
  limit 1;
  return result;
end $$;

create or replace function public.service_record_failed_verification(
  p_token text,p_provider text,p_transaction_ref text,p_expected_amount numeric,
  p_verified_amount numeric,p_error_code text,p_error_message text
) returns uuid language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; provider_key text; created_id uuid;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'verify_payment') then
    raise exception 'Payment verification permission required' using errcode='42501';
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

-- Correct the immutable projection to cover the newly typed facts.
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
    new.verification_evidence_id is distinct from old.verification_evidence_id or
    new.reference_kind is distinct from old.reference_kind or
    new.reference_value is distinct from old.reference_value or
    new.verified_by is distinct from old.verified_by or
    new.unresolved_excess is distinct from old.unresolved_excess
  ) then
    raise exception 'Verified payment values cannot be changed' using errcode='55000';
  end if;
  if new.allocated_tip_amount is distinct from old.allocated_tip_amount and
     new.allocated_tip_amount is distinct from
       (select coalesce(sum(a.amount),0) from public.payment_tip_allocations a
        where a.ticket_id=old.ticket_id and a.business_id=old.business_id) then
    raise exception 'Tip allocation does not match immutable ledger' using errcode='55000';
  end if;
  return new;
end $$;

create or replace function public.request_tip_withdrawal(p_token text,p_amount numeric)
returns public.tip_withdrawal_requests
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; earned numeric; committed numeric;
  created public.tip_withdrawal_requests;
begin
  s:=public.require_staff_session(p_token);
  if p_amount is null or p_amount<=0 then
    raise exception 'Withdrawal amount must be positive' using errcode='22023';
  end if;
  select coalesce(sum(t.tip_amount),0) into earned from public.tickets t
    where t.business_id=s.business_id and t.waiter_id=s.staff_number
      and t.status='settled' and t.financial_state='normal';
  select earned+coalesce(sum(a.amount),0) into earned
    from public.payment_tip_allocations a
    join public.tickets t on t.ticket_id=a.ticket_id
    where a.business_id=s.business_id and a.recipient_staff_number=s.staff_number
      and t.status='settled' and t.financial_state='normal';
  select coalesce(sum(w.amount),0) into committed from public.tip_withdrawal_requests w
    where w.business_id=s.business_id and w.staff_number=s.staff_number
      and w.status in ('pending','approved','paid');
  if p_amount>earned-committed then
    raise exception 'Withdrawal amount exceeds available tip balance' using errcode='22023';
  end if;
  insert into public.tip_withdrawal_requests(business_id,staff_number,amount)
  values(s.business_id,s.staff_number,p_amount) returning * into created;
  return created;
end $$;

create or replace function public.get_receipt_image(p_token text,p_ticket_id uuid)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; receipt public.receipt_images;
begin
  s:=public.require_staff_session(p_token);
  select r.* into receipt from public.receipt_images r
  where r.ticket_id=p_ticket_id and r.business_id=s.business_id
    and (r.waiter_id=s.staff_number or
      public.staff_can(s.business_id,s.staff_number,'review_payment') or
      public.staff_can(s.business_id,s.staff_number,'view_ledger'));
  if not found then return null; end if;
  return jsonb_build_object('mime_type',receipt.mime_type,
    'byte_size',receipt.byte_size,'sha256',receipt.sha256,
    'image_base64',encode(receipt.image_data,'base64'));
end $$;

create or replace function public.list_tip_withdrawal_requests(p_token text)
returns setof public.tip_withdrawal_requests
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if public.staff_can(s.business_id,s.staff_number,'manage_tips') then
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
declare s public.staff_sessions; current_request public.tip_withdrawal_requests;
  changed public.tip_withdrawal_requests;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'manage_tips') then
    raise exception 'Tip management permission required' using errcode='42501';
  end if;
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
  insert into public.tip_payout_ledger
    (business_id,request_id,staff_number,actor_staff_number,action,amount)
  values(s.business_id,p_request_id,current_request.staff_number,s.staff_number,
    p_status,current_request.amount);
  return changed;
end $$;

create or replace function public.allocate_payment_tip(
  p_token text,p_ticket_id uuid,p_recipient_staff_number text,
  p_amount numeric,p_reason text
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; profile public.workspace_profiles; payment public.tickets;
  created public.payment_tip_allocations;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'manage_tips') then
    raise exception 'Tip management permission required' using errcode='42501';
  end if;
  select * into profile from public.workspace_profiles where business_id=s.business_id;
  if not profile.tips_enabled then
    raise exception 'Tips are disabled for this workspace' using errcode='42501';
  end if;
  select * into payment from public.tickets
    where ticket_id=p_ticket_id and business_id=s.business_id
      and verification_evidence_id is not null and status='settled'
      and financial_state='normal' for update;
  if not found then raise exception 'Completed verified payment not found' using errcode='P0002'; end if;
  if p_amount is null or p_amount<=0 or p_amount>payment.unresolved_excess then
    raise exception 'Tip exceeds unresolved excess' using errcode='22023';
  end if;
  if length(btrim(coalesce(p_reason,'')))<3 then
    raise exception 'A reason is required' using errcode='22023';
  end if;
  if not exists (select 1 from public.staff where business_id=s.business_id
    and staff_number=p_recipient_staff_number and is_active) then
    raise exception 'Recipient is not an active workspace member' using errcode='P0002';
  end if;
  if p_recipient_staff_number <> payment.waiter_id then
    raise exception 'Tip recipient must be the member who verified this payment'
      using errcode='22023';
  end if;
  insert into public.payment_tip_allocations
    (business_id,ticket_id,recipient_staff_number,allocated_by,amount,reason)
  values (s.business_id,p_ticket_id,p_recipient_staff_number,s.staff_number,
    p_amount,btrim(p_reason)) returning * into created;
  update public.tickets set allocated_tip_amount=p_amount,updated_at=now()
  where ticket_id=p_ticket_id;
  insert into public.security_audit_log
    (business_id,actor_staff_number,action,subject_type,subject_id,metadata)
  values (s.business_id,s.staff_number,'payment_tip_allocated','ticket',
    p_ticket_id::text,jsonb_build_object('allocation_id',created.allocation_id,
      'amount',p_amount,'recipient',p_recipient_staff_number,
      'remaining_excess',payment.unresolved_excess-p_amount));
  return jsonb_build_object('allocation_id',created.allocation_id,
    'allocated_tip',p_amount,'remaining_excess',payment.unresolved_excess-p_amount);
end $$;
revoke all on function public.allocate_payment_tip(text,uuid,text,numeric,text) from public;
grant execute on function public.allocate_payment_tip(text,uuid,text,numeric,text)
to anon,authenticated;
