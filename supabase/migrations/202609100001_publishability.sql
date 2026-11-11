-- Public release compliance: current legal URLs and a complete, user-initiated
-- staff account deletion flow. Financial rows retain only the non-personal
-- staff reference required for business audit integrity.

create table if not exists public.staff_account_deletion_requests (
  request_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete restrict,
  staff_number text not null,
  reason text,
  status text not null default 'processing'
    check (status in ('processing','completed','failed')),
  requested_at timestamptz not null default now(),
  completed_at timestamptz
);

alter table public.staff_account_deletion_requests enable row level security;
revoke all on public.staff_account_deletion_requests from anon,authenticated;

create or replace function public.delete_current_staff_account(
  p_token text,
  p_reason text default null
) returns public.staff_account_deletion_requests
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  s public.staff_sessions;
  created public.staff_account_deletion_requests;
  anonymous_phone text;
begin
  s := public.require_staff_session(p_token);

  insert into public.staff_account_deletion_requests(
    business_id,staff_number,reason
  ) values (
    s.business_id,s.staff_number,nullif(btrim(p_reason),'')
  ) returning * into created;

  anonymous_phone := 'deleted-' || replace(created.request_id::text,'-','');

  update public.staff
  set
    name='Deleted staff',
    phone_number=anonymous_phone,
    password=null,
    password_hash=extensions.crypt(
      encode(extensions.gen_random_bytes(32),'hex'),
      extensions.gen_salt('bf')
    ),
    is_active=false
  where business_id=s.business_id and staff_number=s.staff_number;

  if not found then
    raise exception 'Staff account not found' using errcode='P0002';
  end if;

  update public.staff_sessions
  set revoked_at=now()
  where business_id=s.business_id
    and staff_number=s.staff_number
    and revoked_at is null;

  update public.staff_account_deletion_requests
  set status='completed',completed_at=now()
  where request_id=created.request_id
  returning * into created;

  insert into public.security_audit_log(
    business_id,actor_staff_number,action,subject_type,subject_id
  ) values (
    s.business_id,s.staff_number,'staff_account_deleted','staff',s.staff_number
  );

  return created;
end $$;

revoke all on function public.delete_current_staff_account(text,text) from public;
grant execute on function public.delete_current_staff_account(text,text) to anon,authenticated;

create table if not exists public.client_error_events (
  event_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  staff_number text not null,
  area text not null check (length(area) between 1 and 48),
  error_code text not null check (length(error_code) between 1 and 96),
  platform text not null check (length(platform) between 1 and 32),
  occurred_at timestamptz not null default now()
);

create index if not exists client_error_events_occurred_at_idx
  on public.client_error_events(occurred_at desc);
alter table public.client_error_events enable row level security;
revoke all on public.client_error_events from anon,authenticated;

create or replace function public.report_client_error(
  p_token text,
  p_area text,
  p_error_code text,
  p_platform text
) returns void
language plpgsql
security definer
set search_path=public,extensions
as $$
declare s public.staff_sessions;
begin
  s := public.require_staff_session(p_token);
  insert into public.client_error_events(
    business_id,staff_number,area,error_code,platform
  ) values (
    s.business_id,
    s.staff_number,
    left(coalesce(nullif(btrim(p_area),''),'unknown'),48),
    left(coalesce(nullif(btrim(p_error_code),''),'unknown'),96),
    left(coalesce(nullif(btrim(p_platform),''),'unknown'),32)
  );
end $$;

revoke all on function public.report_client_error(text,text,text,text) from public;
grant execute on function public.report_client_error(text,text,text,text) to anon,authenticated;

update public.legal_documents set is_current=false where is_current;
insert into public.legal_documents(document_type,version,effective_at,url,is_current)
values
  ('privacy','2026-09-10',now(),'https://beki4kt.github.io/Verify-me/privacy.html',true),
  ('terms','2026-09-10',now(),'https://beki4kt.github.io/Verify-me/terms.html',true)
on conflict(document_type,version) do update set
  effective_at=excluded.effective_at,
  url=excluded.url,
  is_current=true;
