-- Confirmed Supabase Auth identities may request one workspace. A requested
-- plan is never treated as a paid or active subscription.
alter table public.businesses drop constraint if exists businesses_subscription_status_check;
alter table public.businesses add constraint businesses_subscription_status_check
  check (subscription_status in
    ('pending_activation','trial','active','overdue','grace_period','cancelled','suspended'));

create table public.workspace_owner_identities (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  business_id uuid not null unique references public.businesses(business_id) on delete cascade,
  staff_number text not null,
  requested_billing_period text not null check (requested_billing_period in ('monthly','quarterly')),
  created_at timestamptz not null default now(),
  unique (business_id,staff_number),
  foreign key (business_id,staff_number)
    references public.staff(business_id,staff_number) on delete cascade
);
alter table public.workspace_owner_identities enable row level security;
revoke all on public.workspace_owner_identities from public,anon,authenticated;

create or replace function public.my_owner_registration() returns jsonb
language plpgsql security definer set search_path=public,auth as $$
declare user_id uuid := auth.uid(); result jsonb;
begin
  if user_id is null then return null; end if;
  select jsonb_build_object(
    'business_id',b.business_id,'business_name',b.name,
    'business_code',b.business_code,'subscription_status',b.subscription_status,
    'is_active',b.is_active,'use_case',wp.use_case,
    'requested_billing_period',oi.requested_billing_period)
  into result from public.workspace_owner_identities oi
  join public.businesses b on b.business_id=oi.business_id
  join public.workspace_profiles wp on wp.business_id=b.business_id
  where oi.auth_user_id=user_id;
  return result;
end $$;

-- Member managers need the member's current phone when resetting a staff
-- password through the existing update RPC; it remains behind staff_can.
create or replace function public.list_workspace_members(p_token text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; result jsonb;
begin
  s:=public.require_staff_session(p_token);
  if not public.staff_can(s.business_id,s.staff_number,'manage_members') then
    raise exception 'Member management permission required' using errcode='42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'staff_number',st.staff_number,'name',st.name,'phone_number',st.phone_number,
    'role',st.role,'is_active',st.is_active,
    'capabilities',jsonb_build_object(
      'verify_payment',public.staff_can(st.business_id,st.staff_number,'verify_payment'),
      'review_payment',public.staff_can(st.business_id,st.staff_number,'review_payment'),
      'view_ledger',public.staff_can(st.business_id,st.staff_number,'view_ledger'),
      'manage_receiving_accounts',public.staff_can(st.business_id,st.staff_number,'manage_receiving_accounts'),
      'manage_members',public.staff_can(st.business_id,st.staff_number,'manage_members'),
      'manage_workspace',public.staff_can(st.business_id,st.staff_number,'manage_workspace'),
      'manage_tips',public.staff_can(st.business_id,st.staff_number,'manage_tips')))
    order by st.created_at),'[]'::jsonb) into result
  from public.staff st where st.business_id=s.business_id;
  return result;
end $$;

create or replace function public.service_operator_registration_requests() returns jsonb
language sql security definer set search_path=public,auth as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'business_id',oi.business_id,'owner_email',u.email,
    'billing_period',oi.requested_billing_period,
    'created_at',oi.created_at) order by oi.created_at desc),'[]'::jsonb)
  from public.workspace_owner_identities oi
  join auth.users u on u.id=oi.auth_user_id
  join public.businesses b on b.business_id=oi.business_id
  where b.subscription_status='pending_activation'
$$;
revoke all on function public.service_operator_registration_requests() from public,anon,authenticated;
grant execute on function public.service_operator_registration_requests() to service_role;

create or replace function public.request_owner_workspace(
  p_name text,p_owner_name text,p_owner_phone text,p_use_case text,
  p_reference_kind text,p_review_policy text,p_team boolean,
  p_plan text,p_billing_period text,p_provider text,p_receiving_account text
) returns jsonb language plpgsql security definer set search_path=public,auth,extensions as $$
declare user_id uuid := auth.uid(); owner_email text; confirmed_at timestamptz;
  created public.businesses; generated_code text; owner_number text;
  default_kind text; provider_key text; attempt integer;
begin
  if user_id is null then raise exception 'Sign in to create a workspace' using errcode='42501'; end if;
  select u.email,u.email_confirmed_at into owner_email,confirmed_at
    from auth.users u where u.id=user_id;
  if confirmed_at is null or owner_email is null then
    raise exception 'Confirm your email before creating a workspace' using errcode='42501';
  end if;
  if exists(select 1 from public.workspace_owner_identities where auth_user_id=user_id) then
    raise exception 'This owner already has a workspace' using errcode='23505';
  end if;
  if length(btrim(coalesce(p_name,''))) not between 2 and 120 or
     length(btrim(coalesce(p_owner_name,''))) not between 2 and 120 or
     coalesce(p_owner_phone,'') !~ '^\+251[79][0-9]{8}$' then
    raise exception 'Enter a business name, owner name and valid +251 phone' using errcode='22023';
  end if;
  if p_use_case not in ('general','personal','shop','restaurant','service') or
     p_reference_kind not in ('none','invoice','order','booking','customer','table','note') or
     p_review_policy not in ('automatic','review_required') or
     p_plan not in ('basic','pro') or
     p_billing_period not in ('monthly','quarterly') or p_team is null then
    raise exception 'Invalid workspace choices' using errcode='22023';
  end if;
  if p_team and p_plan='basic' then
    raise exception 'Choose Pro to add team members' using errcode='22023';
  end if;
  provider_key:=lower(regexp_replace(coalesce(p_provider,''),'[^a-z0-9]','','g'));
  if provider_key not in ('telebirr','cbe','cbebirr','dashen','abyssinia','mpesa') or
     length(btrim(coalesce(p_receiving_account,''))) not between 6 and 80 then
    raise exception 'Select a provider and enter its receiving account' using errcode='22023';
  end if;
  default_kind:=p_reference_kind;
  owner_number:='OWNER-'||upper(substr(replace(user_id::text,'-',''),1,12));
  for attempt in 1..5 loop
    generated_code:='CK-'||upper(encode(extensions.gen_random_bytes(5),'hex'));
    exit when not exists(select 1 from public.businesses where business_code=generated_code);
  end loop;
  insert into public.businesses(
    name,business_code,subscription_tier,subscription_status,
    max_staff_limit,has_cashier_module,is_active,bank_accounts
  ) values (
    btrim(p_name),generated_code,p_plan,'pending_activation',
    case when p_plan='basic' then 1 else 2147483647 end,p_plan='pro',false,
    jsonb_build_object(provider_key||'_number',btrim(p_receiving_account))
  ) returning * into created;
  -- The staff password is unknown to the owner; confirmed Auth is the sole
  -- owner login. Existing team members keep their current staff credentials.
  insert into public.staff(staff_number,business_id,name,phone_number,password,role,is_active)
  values(owner_number,created.business_id,btrim(p_owner_name),p_owner_phone,
    encode(extensions.gen_random_bytes(32),'hex'),'admin',true);
  update public.workspace_profiles set
    use_case=p_use_case,default_reference_kind=default_kind,
    review_policy=p_review_policy,tips_enabled=false,overpayment_policy='unresolved'
  where business_id=created.business_id;
  insert into public.workspace_owner_identities
    (auth_user_id,business_id,staff_number,requested_billing_period)
  values(user_id,created.business_id,owner_number,p_billing_period);
  insert into public.security_audit_log
    (business_id,actor_staff_number,action,subject_type,subject_id,metadata)
  values(created.business_id,owner_number,'owner_registration_requested','business',
    created.business_id::text,jsonb_build_object('plan',p_plan,'billing_period',p_billing_period));
  return public.my_owner_registration();
end $$;

create or replace function public.start_owner_workspace_session() returns jsonb
language plpgsql security definer set search_path=public,auth,extensions as $$
declare user_id uuid := auth.uid(); identity public.workspace_owner_identities;
  business public.businesses; member public.staff; raw_token text;
begin
  if user_id is null then raise exception 'Sign in first' using errcode='42501'; end if;
  if not exists(select 1 from auth.users u
      where u.id=user_id and u.email_confirmed_at is not null) then
    raise exception 'Confirm your email before opening this workspace' using errcode='42501';
  end if;
  select * into identity from public.workspace_owner_identities where auth_user_id=user_id;
  if not found then raise exception 'No registered workspace' using errcode='P0002'; end if;
  select * into business from public.businesses where business_id=identity.business_id;
  if not public.subscription_has_access(business) then
    raise exception 'Workspace activation is pending' using errcode='42501';
  end if;
  select * into member from public.staff where business_id=identity.business_id
    and staff_number=identity.staff_number and is_active;
  if not found then raise exception 'Owner account is unavailable' using errcode='42501'; end if;
  raw_token:=encode(extensions.gen_random_bytes(32),'hex');
  insert into public.staff_sessions(token_hash,business_id,staff_number,role,expires_at)
  values(extensions.digest(convert_to(raw_token,'UTF8'),'sha256'),
    business.business_id,member.staff_number,member.role,now()+interval '12 hours');
  return jsonb_build_object('token',raw_token,'business_id',business.business_id,
    'business_name',business.name,'staff_number',member.staff_number,'role',member.role,
    'max_staff_limit',business.max_staff_limit,
    'has_cashier_module',business.has_cashier_module,'expires_at',now()+interval '12 hours');
end $$;

revoke all on function public.my_owner_registration() from public,anon;
revoke all on function public.request_owner_workspace(text,text,text,text,text,text,boolean,text,text,text,text) from public,anon;
revoke all on function public.start_owner_workspace_session() from public,anon;
grant execute on function public.my_owner_registration() to authenticated;
grant execute on function public.request_owner_workspace(text,text,text,text,text,text,boolean,text,text,text,text) to authenticated;
grant execute on function public.start_owner_workspace_session() to authenticated;

-- A pending request must be reviewed through the existing plan-and-access
-- action. Toggling the separate business-active switch cannot activate it.
create or replace function public.service_operator_set_business_active(
  p_operator_email text,p_business_id uuid,p_active boolean,p_reason text default null
) returns void language plpgsql security definer set search_path=public as $$
declare current_status text;
begin
  select subscription_status into current_status from public.businesses
    where business_id=p_business_id for update;
  if not found then raise exception 'Business not found' using errcode='P0002'; end if;
  if p_active and current_status='pending_activation' then
    raise exception 'Review and activate the requested plan first' using errcode='42501';
  end if;
  update public.businesses set is_active=p_active where business_id=p_business_id;
  if not p_active then
    update public.staff_sessions set revoked_at=now()
    where business_id=p_business_id and revoked_at is null;
  end if;
  perform public.service_operator_record_audit(
    p_operator_email,'business_status_changed','business',p_business_id::text,
    jsonb_build_object('active',p_active,'reason',nullif(btrim(p_reason),''))
  );
end $$;
