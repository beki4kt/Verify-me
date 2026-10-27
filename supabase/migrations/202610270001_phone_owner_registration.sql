-- Prepared Phase 3 migration. Do not apply to the shared project until
-- Supabase phone Auth/SMS, abuse controls and the owner recovery process pass
-- acceptance. Existing email owners retain the same auth_user_id and workspace.

create or replace function public.request_owner_workspace(
  p_name text,p_owner_name text,p_owner_phone text,p_use_case text,
  p_reference_kind text,p_review_policy text,p_team boolean,
  p_plan text,p_billing_period text,p_provider text,p_receiving_account text
) returns jsonb language plpgsql security definer
set search_path=public,auth,extensions as $$
declare user_id uuid := auth.uid(); owner_email text; confirmed_email_at timestamptz;
  auth_phone text; confirmed_phone_at timestamptz;
  created public.businesses; generated_code text; owner_number text;
  provider_key text; attempt integer;
begin
  if user_id is null then
    raise exception 'Sign in to create a workspace' using errcode='42501';
  end if;
  -- Serializes repeated requests from the same Auth identity. A completed
  -- request is returned unchanged, including after a lost network response.
  select u.email,u.email_confirmed_at,u.phone,u.phone_confirmed_at
    into owner_email,confirmed_email_at,auth_phone,confirmed_phone_at
    from auth.users u where u.id=user_id for update;
  if not found then
    raise exception 'Owner identity is unavailable' using errcode='42501';
  end if;
  if exists(select 1 from public.workspace_owner_identities
      where auth_user_id=user_id) then
    return public.my_owner_registration();
  end if;
  if length(btrim(coalesce(p_name,''))) not between 2 and 120 or
     length(btrim(coalesce(p_owner_name,''))) not between 2 and 120 or
     coalesce(p_owner_phone,'') !~ '^\+251[79][0-9]{8}$' then
    raise exception 'Enter a business name, owner name and valid +251 phone'
      using errcode='22023';
  end if;
  -- New phone owners must prove ownership of the submitted phone. Existing
  -- confirmed-email owners continue to use their current identity and do
  -- not receive an automatic second owner account.
  if confirmed_email_at is null and not (
    confirmed_phone_at is not null and auth_phone=p_owner_phone
  ) then
    raise exception 'Confirm your owner identity before registration'
      using errcode='42501';
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
    raise exception 'Select a provider and enter its receiving account'
      using errcode='22023';
  end if;
  owner_number:='OWNER-'||upper(substr(replace(user_id::text,'-',''),1,12));
  for attempt in 1..5 loop
    generated_code:='CK-'||upper(encode(extensions.gen_random_bytes(5),'hex'));
    exit when not exists(select 1 from public.businesses
      where business_code=generated_code);
  end loop;
  insert into public.businesses(
    name,business_code,subscription_tier,subscription_status,
    max_staff_limit,has_cashier_module,is_active,bank_accounts
  ) values (
    btrim(p_name),generated_code,p_plan,'pending_activation',
    case when p_plan='basic' then 1 else 2147483647 end,p_plan='pro',false,
    jsonb_build_object(provider_key||'_number',btrim(p_receiving_account))
  ) returning * into created;
  -- Supabase Auth is the only owner login. The random legacy staff password
  -- is never shown to or chosen by the registering owner.
  insert into public.staff(staff_number,business_id,name,phone_number,password,role,is_active)
  values(owner_number,created.business_id,btrim(p_owner_name),p_owner_phone,
    encode(extensions.gen_random_bytes(32),'hex'),'admin',true);
  update public.workspace_profiles set
    use_case=p_use_case,default_reference_kind=p_reference_kind,
    review_policy=p_review_policy,tips_enabled=false,overpayment_policy='unresolved'
  where business_id=created.business_id;
  insert into public.workspace_owner_identities
    (auth_user_id,business_id,staff_number,requested_billing_period)
  values(user_id,created.business_id,owner_number,p_billing_period);
  insert into public.security_audit_log
    (business_id,actor_staff_number,action,subject_type,subject_id,metadata)
  values(created.business_id,owner_number,'owner_registration_requested','business',
    created.business_id::text,jsonb_build_object(
      'plan',p_plan,'billing_period',p_billing_period,
      'identity_method',case when confirmed_email_at is not null
        then 'confirmed_email' else 'confirmed_phone' end));
  return public.my_owner_registration();
end $$;

create or replace function public.start_owner_workspace_session() returns jsonb
language plpgsql security definer set search_path=public,auth,extensions as $$
declare user_id uuid := auth.uid(); identity public.workspace_owner_identities;
  business public.businesses; member public.staff; raw_token text;
  owner_email_confirmed_at timestamptz; owner_phone_confirmed_at timestamptz;
  auth_phone text;
begin
  if user_id is null then
    raise exception 'Sign in first' using errcode='42501';
  end if;
  select * into identity from public.workspace_owner_identities
    where auth_user_id=user_id;
  if not found then
    raise exception 'No registered workspace' using errcode='P0002';
  end if;
  select * into member from public.staff where business_id=identity.business_id
    and staff_number=identity.staff_number and is_active;
  if not found then
    raise exception 'Owner account is unavailable' using errcode='42501';
  end if;
  select u.email_confirmed_at,u.phone_confirmed_at,u.phone
    into owner_email_confirmed_at,owner_phone_confirmed_at,auth_phone
    from auth.users u where u.id=user_id;
  if owner_email_confirmed_at is null and not (
    owner_phone_confirmed_at is not null and auth_phone=member.phone_number
  ) then
    raise exception 'Confirm your owner identity before opening this workspace'
      using errcode='42501';
  end if;
  select * into business from public.businesses
    where business_id=identity.business_id;
  if not public.subscription_has_access(business) then
    raise exception 'Workspace activation is pending or unavailable'
      using errcode='42501';
  end if;
  raw_token:=encode(extensions.gen_random_bytes(32),'hex');
  insert into public.staff_sessions(token_hash,business_id,staff_number,role,expires_at)
  values(extensions.digest(convert_to(raw_token,'UTF8'),'sha256'),
    business.business_id,member.staff_number,member.role,now()+interval '12 hours');
  return jsonb_build_object('token',raw_token,'business_id',business.business_id,
    'business_name',business.name,'staff_number',member.staff_number,'role',member.role,
    'max_staff_limit',business.max_staff_limit,
    'has_cashier_module',business.has_cashier_module,
    'expires_at',now()+interval '12 hours');
end $$;

revoke all on function public.request_owner_workspace(
  text,text,text,text,text,text,boolean,text,text,text,text
) from public,anon;
revoke all on function public.start_owner_workspace_session() from public,anon;
grant execute on function public.request_owner_workspace(
  text,text,text,text,text,text,boolean,text,text,text,text
) to authenticated;
grant execute on function public.start_owner_workspace_session() to authenticated;
