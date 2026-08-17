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
