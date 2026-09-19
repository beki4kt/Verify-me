-- CHEKMI product experience and operations additions.
-- This migration is additive and safe to apply after 202609100001_publishability.sql.

create or replace function public.list_my_legal_consents(p_token text)
returns table(document_type text,document_version text,accepted_at timestamptz)
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  return query
    select c.document_type,c.document_version,c.accepted_at
    from public.staff_consents c
    where c.business_id=s.business_id and c.staff_number=s.staff_number
    order by c.accepted_at desc;
end $$;

revoke all on function public.list_my_legal_consents(text) from public;
grant execute on function public.list_my_legal_consents(text) to anon,authenticated;

alter table public.support_cases
  add column if not exists owner_response text,
  add column if not exists responded_at timestamptz,
  add column if not exists responded_by text;

create or replace function public.service_operator_reply_support_case(
  p_operator_email text,p_case_id uuid,p_response text,p_status text default 'in_progress'
) returns void
language plpgsql security definer set search_path=public as $$
begin
  if length(btrim(coalesce(p_response,''))) not between 2 and 4000 then
    raise exception 'Support response must be between 2 and 4000 characters' using errcode='22023';
  end if;
  if p_status not in ('open','in_progress','resolved','closed') then
    raise exception 'Invalid support status' using errcode='22023';
  end if;
  update public.support_cases set
    owner_response=btrim(p_response),responded_at=now(),responded_by=lower(btrim(p_operator_email)),
    status=p_status,updated_at=now()
  where case_id=p_case_id;
  if not found then raise exception 'Support case not found' using errcode='P0002'; end if;
  perform public.service_operator_record_audit(
    p_operator_email,'support_case_replied','support_case',p_case_id::text,
    jsonb_build_object('status',p_status,'response_length',length(btrim(p_response)))
  );
end $$;

revoke all on function public.service_operator_reply_support_case(text,uuid,text,text) from public,anon,authenticated;
grant execute on function public.service_operator_reply_support_case(text,uuid,text,text) to service_role;

create or replace function public.service_operator_list_support_cases()
returns jsonb
language sql security definer set search_path=public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'case_id',c.case_id,'business_id',c.business_id,'business_name',b.name,
    'opened_by',c.opened_by,'category',c.category,'subject',c.subject,
    'description',c.description,'priority',c.priority,'status',c.status,
    'owner_response',c.owner_response,'responded_at',c.responded_at,
    'responded_by',c.responded_by,'created_at',c.created_at,'updated_at',c.updated_at
  ) order by c.created_at desc),'[]'::jsonb)
  from public.support_cases c left join public.businesses b on b.business_id=c.business_id
$$;

revoke all on function public.service_operator_list_support_cases() from public,anon,authenticated;
grant execute on function public.service_operator_list_support_cases() to service_role;

create or replace function public.list_business_audit_events(
  p_token text,p_limit integer default 200
) returns table(
  event_id text,actor_staff_number text,action text,subject_type text,
  subject_id text,details jsonb,created_at timestamptz
)
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; safe_limit integer;
begin
  s:=public.require_staff_session(p_token);
  if s.role<>'admin' then
    raise exception 'Administrator role required' using errcode='42501';
  end if;
  safe_limit:=least(greatest(coalesce(p_limit,200),1),500);
  return query
    select events.event_id,events.actor_staff_number,events.action,
      events.subject_type,events.subject_id,events.details,events.created_at
    from (
      select 'security:'||a.audit_id::text as event_id,a.actor_staff_number,a.action,
        a.subject_type,a.subject_id,a.metadata as details,a.created_at
      from public.security_audit_log a where a.business_id=s.business_id
      union all
      select 'ticket:'||f.event_id::text,f.actor_staff_number,f.action,
        'ticket'::text,f.ticket_id::text,
        f.metadata||jsonb_build_object(
          'previous_status',f.previous_status,'new_status',f.new_status,
          'reason',f.reason,'amount',f.amount
        ),f.created_at
      from public.ticket_financial_events f where f.business_id=s.business_id
      union all
      select 'payout:'||p.payout_event_id::text,p.actor_staff_number,p.action,
        'tip_withdrawal'::text,p.request_id::text,
        jsonb_build_object('staff_number',p.staff_number,'amount',p.amount),p.created_at
      from public.tip_payout_ledger p where p.business_id=s.business_id
    ) events
    order by events.created_at desc
    limit safe_limit;
end $$;

revoke all on function public.list_business_audit_events(text,integer) from public;
grant execute on function public.list_business_audit_events(text,integer) to anon,authenticated;

insert into public.chekmi_schema_meta(singleton,schema_version,applied_at)
values(true,'2026-09-19.1',now())
on conflict(singleton) do update set
  schema_version=excluded.schema_version,
  applied_at=excluded.applied_at;
