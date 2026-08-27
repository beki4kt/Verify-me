-- Server-only platform operator console. Credentials and MFA are verified by
-- the TypeScript API; these functions remain service-role only and every
-- privileged mutation writes an immutable operator audit entry.

create table if not exists public.operator_audit_log (
  audit_id bigint generated always as identity primary key,
  operator_email text not null,
  action text not null,
  subject_type text not null,
  subject_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists operator_audit_created_idx
  on public.operator_audit_log(created_at desc);
alter table public.operator_audit_log enable row level security;
revoke all on public.operator_audit_log from public,anon,authenticated;

create or replace function public.service_operator_record_audit(
  p_operator_email text,p_action text,p_subject_type text,p_subject_id text,p_metadata jsonb default '{}'::jsonb
) returns void
language plpgsql security definer set search_path=public as $$
begin
  insert into public.operator_audit_log(operator_email,action,subject_type,subject_id,metadata)
  values(lower(btrim(p_operator_email)),btrim(p_action),btrim(p_subject_type),nullif(btrim(p_subject_id),''),coalesce(p_metadata,'{}'::jsonb));
end $$;

create or replace function public.service_operator_snapshot() returns jsonb
language plpgsql security definer set search_path=public as $$
begin
  return jsonb_build_object(
    'metrics',jsonb_build_object(
      'businesses',(select count(*) from public.businesses),
      'active_businesses',(select count(*) from public.businesses where is_active and subscription_status not in ('suspended','cancelled')),
      'attention_businesses',(select count(*) from public.businesses where not is_active or subscription_status in ('overdue','grace_period','suspended','cancelled')),
      'active_sessions',(select count(*) from public.staff_sessions where revoked_at is null and expires_at>now()),
      'open_support_cases',(select count(*) from public.support_cases where status in ('open','in_progress')),
      'open_invoices',(select count(*) from public.subscription_invoices where status='open')
    ),
    'businesses',coalesce((
      select jsonb_agg(jsonb_build_object(
        'business_id',b.business_id,'name',b.name,'business_code',b.business_code,'address',b.address,
        'subscription_tier',b.subscription_tier,'subscription_status',b.subscription_status,
        'subscription_started_at',b.subscription_started_at,'subscription_ends_at',b.subscription_ends_at,
        'grace_ends_at',b.grace_ends_at,'max_staff_limit',b.max_staff_limit,
        'has_cashier_module',b.has_cashier_module,'is_active',b.is_active,'created_at',b.created_at,
        'staff_count',(select count(*) from public.staff st where st.business_id=b.business_id),
        'active_staff_count',(select count(*) from public.staff st where st.business_id=b.business_id and st.is_active),
        'active_sessions',(select count(*) from public.staff_sessions ss where ss.business_id=b.business_id and ss.revoked_at is null and ss.expires_at>now()),
        'ticket_count',(select count(*) from public.tickets t where t.business_id=b.business_id)
      ) order by b.created_at desc) from public.businesses b
    ),'[]'::jsonb),
    'support_cases',coalesce((
      select jsonb_agg(jsonb_build_object(
        'case_id',c.case_id,'business_id',c.business_id,'business_name',b.name,'opened_by',c.opened_by,
        'category',c.category,'subject',c.subject,'description',c.description,'priority',c.priority,
        'status',c.status,'created_at',c.created_at,'updated_at',c.updated_at
      ) order by c.created_at desc)
      from public.support_cases c left join public.businesses b on b.business_id=c.business_id
    ),'[]'::jsonb),
    'deletion_requests',coalesce((
      select jsonb_agg(jsonb_build_object(
        'request_id',r.request_id,'business_id',r.business_id,'business_name',b.name,
        'requested_by',r.requested_by,'reason',r.reason,'status',r.status,'requested_at',r.requested_at,
        'reviewed_at',r.reviewed_at,'reviewed_by',r.reviewed_by,'review_notes',r.review_notes
      ) order by r.requested_at desc)
      from public.account_deletion_requests r join public.businesses b on b.business_id=r.business_id
    ),'[]'::jsonb),
    'invoices',coalesce((
      select jsonb_agg(jsonb_build_object(
        'invoice_id',i.invoice_id,'business_id',i.business_id,'business_name',b.name,
        'invoice_number',i.invoice_number,'plan_tier',i.plan_tier,'amount',i.amount,'currency',i.currency,
        'status',i.status,'period_start',i.period_start,'period_end',i.period_end,
        'due_at',i.due_at,'paid_at',i.paid_at,'created_at',i.created_at
      ) order by i.created_at desc)
      from public.subscription_invoices i join public.businesses b on b.business_id=i.business_id
    ),'[]'::jsonb),
    'operator_audit',coalesce((
      select jsonb_agg(to_jsonb(a) order by a.created_at desc)
      from (select * from public.operator_audit_log order by created_at desc limit 100) a
    ),'[]'::jsonb)
  );
end $$;

create or replace function public.service_operator_create_business(
  p_operator_email text,p_name text,p_business_code text,p_address text,p_tier text,p_status text,
  p_max_staff integer,p_has_cashier boolean,p_admin_name text,p_admin_phone text,p_admin_password text,p_admin_pin text
) returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare created public.businesses;
begin
  if length(btrim(p_name))<2 then raise exception 'Restaurant name is required' using errcode='22023'; end if;
  if upper(btrim(p_business_code))!~'^[A-Z0-9-]{3,32}$' then raise exception 'Invalid workspace code' using errcode='22023'; end if;
  if p_tier not in ('starter','basic','pro') then raise exception 'Invalid subscription tier' using errcode='22023'; end if;
  if p_status not in ('trial','active','overdue','grace_period','cancelled','suspended') then raise exception 'Invalid subscription status' using errcode='22023'; end if;
  if p_max_staff<1 then raise exception 'Staff limit must be positive' using errcode='22023'; end if;
  if length(coalesce(p_admin_password,''))<10 then raise exception 'Root-admin password must be at least 10 characters' using errcode='22023'; end if;
  insert into public.businesses(
    name,business_code,address,subscription_tier,subscription_status,subscription_started_at,
    subscription_ends_at,max_staff_limit,has_cashier_module,is_active
  ) values (
    btrim(p_name),upper(btrim(p_business_code)),nullif(btrim(p_address),''),p_tier,p_status,now(),
    case when p_status='trial' then now()+interval '14 days' else null end,
    p_max_staff,p_has_cashier,p_status not in ('cancelled','suspended')
  ) returning * into created;
  insert into public.staff(staff_number,business_id,name,phone_number,password,role,is_active)
  values(btrim(p_admin_pin),created.business_id,btrim(p_admin_name),btrim(p_admin_phone),p_admin_password,'admin',true);
  perform public.service_operator_record_audit(
    p_operator_email,'business_created','business',created.business_id::text,
    jsonb_build_object('name',created.name,'business_code',created.business_code,'tier',p_tier,'root_admin',btrim(p_admin_pin))
  );
  return jsonb_build_object('business_id',created.business_id,'name',created.name,'business_code',created.business_code);
end $$;

create or replace function public.service_operator_set_business_active(
  p_operator_email text,p_business_id uuid,p_active boolean,p_reason text default null
) returns void
language plpgsql security definer set search_path=public as $$
begin
  update public.businesses set is_active=p_active where business_id=p_business_id;
  if not found then raise exception 'Business not found' using errcode='P0002'; end if;
  if not p_active then
    update public.staff_sessions set revoked_at=now()
    where business_id=p_business_id and revoked_at is null;
  end if;
  perform public.service_operator_record_audit(
    p_operator_email,'business_status_changed','business',p_business_id::text,
    jsonb_build_object('active',p_active,'reason',nullif(btrim(p_reason),''))
  );
end $$;

create or replace function public.service_operator_update_subscription(
  p_operator_email text,p_business_id uuid,p_tier text,p_status text,p_ends_at timestamptz,
  p_grace_ends_at timestamptz,p_max_staff integer,p_has_cashier boolean
) returns void
language plpgsql security definer set search_path=public as $$
begin
  if p_tier not in ('starter','basic','pro') then raise exception 'Invalid subscription tier' using errcode='22023'; end if;
  if p_status not in ('trial','active','overdue','grace_period','cancelled','suspended') then raise exception 'Invalid subscription status' using errcode='22023'; end if;
  if p_max_staff<1 then raise exception 'Staff limit must be positive' using errcode='22023'; end if;
  update public.businesses set
    subscription_tier=p_tier,subscription_status=p_status,subscription_ends_at=p_ends_at,
    grace_ends_at=p_grace_ends_at,max_staff_limit=p_max_staff,has_cashier_module=p_has_cashier,
    is_active=p_status not in ('cancelled','suspended'),
    cancelled_at=case when p_status='cancelled' then now() else null end
  where business_id=p_business_id;
  if not found then raise exception 'Business not found' using errcode='P0002'; end if;
  if p_status in ('cancelled','suspended') then
    update public.staff_sessions set revoked_at=now()
    where business_id=p_business_id and revoked_at is null;
  end if;
  perform public.service_operator_record_audit(
    p_operator_email,'subscription_updated','business',p_business_id::text,
    jsonb_build_object('tier',p_tier,'status',p_status,'max_staff',p_max_staff,'has_cashier',p_has_cashier)
  );
end $$;

create or replace function public.service_operator_revoke_business_sessions(
  p_operator_email text,p_business_id uuid,p_reason text default null
) returns integer
language plpgsql security definer set search_path=public as $$
declare changed integer;
begin
  update public.staff_sessions set revoked_at=now()
  where business_id=p_business_id and revoked_at is null and expires_at>now();
  get diagnostics changed=row_count;
  perform public.service_operator_record_audit(
    p_operator_email,'business_sessions_revoked','business',p_business_id::text,
    jsonb_build_object('revoked',changed,'reason',nullif(btrim(p_reason),''))
  );
  return changed;
end $$;

create or replace function public.service_operator_update_support_case(
  p_operator_email text,p_case_id uuid,p_status text
) returns void
language plpgsql security definer set search_path=public as $$
begin
  if p_status not in ('open','in_progress','resolved','closed') then raise exception 'Invalid support status' using errcode='22023'; end if;
  update public.support_cases set status=p_status,updated_at=now() where case_id=p_case_id;
  if not found then raise exception 'Support case not found' using errcode='P0002'; end if;
  perform public.service_operator_record_audit(
    p_operator_email,'support_case_updated','support_case',p_case_id::text,jsonb_build_object('status',p_status)
  );
end $$;

create or replace function public.service_operator_review_deletion(
  p_operator_email text,p_request_id uuid,p_status text,p_notes text default null
) returns void
language plpgsql security definer set search_path=public as $$
begin
  if p_status not in ('pending_review','retention_hold','approved','rejected') then
    raise exception 'Completion requires the separate audited retention job' using errcode='22023';
  end if;
  update public.account_deletion_requests set
    status=p_status,reviewed_at=now(),reviewed_by=lower(btrim(p_operator_email)),review_notes=nullif(btrim(p_notes),'')
  where request_id=p_request_id;
  if not found then raise exception 'Deletion request not found' using errcode='P0002'; end if;
  perform public.service_operator_record_audit(
    p_operator_email,'deletion_request_reviewed','deletion_request',p_request_id::text,jsonb_build_object('status',p_status)
  );
end $$;

revoke all on function public.service_operator_record_audit(text,text,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.service_operator_snapshot() from public,anon,authenticated;
revoke all on function public.service_operator_create_business(text,text,text,text,text,text,integer,boolean,text,text,text,text) from public,anon,authenticated;
revoke all on function public.service_operator_set_business_active(text,uuid,boolean,text) from public,anon,authenticated;
revoke all on function public.service_operator_update_subscription(text,uuid,text,text,timestamptz,timestamptz,integer,boolean) from public,anon,authenticated;
revoke all on function public.service_operator_revoke_business_sessions(text,uuid,text) from public,anon,authenticated;
revoke all on function public.service_operator_update_support_case(text,uuid,text) from public,anon,authenticated;
revoke all on function public.service_operator_review_deletion(text,uuid,text,text) from public,anon,authenticated;
grant execute on function public.service_operator_record_audit(text,text,text,text,jsonb) to service_role;
grant execute on function public.service_operator_snapshot() to service_role;
grant execute on function public.service_operator_create_business(text,text,text,text,text,text,integer,boolean,text,text,text,text) to service_role;
grant execute on function public.service_operator_set_business_active(text,uuid,boolean,text) to service_role;
grant execute on function public.service_operator_update_subscription(text,uuid,text,text,timestamptz,timestamptz,integer,boolean) to service_role;
grant execute on function public.service_operator_revoke_business_sessions(text,uuid,text) to service_role;
grant execute on function public.service_operator_update_support_case(text,uuid,text) to service_role;
grant execute on function public.service_operator_review_deletion(text,uuid,text,text) to service_role;
