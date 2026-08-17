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
