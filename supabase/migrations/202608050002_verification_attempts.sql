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
