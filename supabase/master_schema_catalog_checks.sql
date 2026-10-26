-- Read-only catalog checks for reconciling the existing Chekmi master database.
-- Run in the Supabase SQL Editor after mesob_readiness.sql. This reads schema
-- metadata only: no customer rows, passwords, receipt contents, or tokens.
-- Share the result table, including rows whose present value is false.
with
expected_functions(signature) as (values
  ('public.require_staff_session(text)'),
  ('public.hash_staff_password()'),
  ('public.subscription_has_access(public.businesses)'),
  ('public.staff_can(uuid,text,text)'),
  ('public.commit_verified_payment(text,text,text,text,numeric,numeric,text,text,text,text,text,timestamptz,text,jsonb,text)'),
  ('public.create_workspace_profile()'),
  ('public.apply_cashier_verify_preset()'),
  ('public.prevent_financial_evidence_mutation()'),
  ('public.protect_verified_ticket_values()'),
  ('public.protect_archived_receipt_original()'),
  ('public.create_missing_receipt_evidence()'),
  ('public.reject_known_cross_workspace_payment_duplicate()'),
  ('public.reserve_receipt_original(text,uuid,text,integer,text,text)'),
  ('public.finish_receipt_original(text,uuid,text)'),
  ('public.fail_receipt_original(text,uuid,text)'),
  ('public.service_get_receipt_original_locator(text,uuid)'),
  ('public.get_verified_receipt_detail(text,uuid)'),
  ('public.request_owner_workspace(text,text,text,text,text,text,boolean,text,text,text,text)')
),
expected_triggers(schema_name, table_name, trigger_name) as (values
  ('public','businesses','businesses_create_workspace_profile'),
  ('public','staff','staff_apply_cashier_verify_preset'),
  ('public','tickets','verified_ticket_missing_receipt'),
  ('public','receipt_images','receipt_original_immutable'),
  ('public','payment_verification_evidence','known_cross_workspace_payment_duplicate'),
  ('public','payment_tip_allocations','payment_tip_allocations_immutable')
),
expected_constraints(schema_name, table_name, constraint_name) as (values
  ('public','businesses','businesses_subscription_status_check'),
  ('public','tickets','tickets_unresolved_excess_nonnegative'),
  ('public','payment_verification_evidence','evidence_unresolved_excess_nonnegative'),
  ('public','receipt_images','receipt_images_archive_size_check'),
  ('public','receipt_images','receipt_images_archive_status_check'),
  ('public','receipt_images','receipt_images_archive_source_check'),
  ('public','receipt_images','receipt_images_archive_original_check')
),
expected_policies(schema_name, table_name, policy_name) as (values
  ('storage','objects','receipt_evidence_private_clients'),
  ('public','legal_documents','legal_documents_read_current')
),
checks as (
  select 'function'::text as kind, f.signature as object_name,
    p.oid is not null as present,
    jsonb_build_object(
      'security_definer',p.prosecdef,
      'search_path',p.proconfig,
      'anon_execute',case when p.oid is not null then has_function_privilege('anon',p.oid,'EXECUTE') end,
      'authenticated_execute',case when p.oid is not null then has_function_privilege('authenticated',p.oid,'EXECUTE') end,
      'service_execute',case when p.oid is not null then has_function_privilege('service_role',p.oid,'EXECUTE') end,
      'definition_md5',case when p.oid is not null then md5(pg_get_functiondef(p.oid)) end
    ) as details
  from expected_functions f
  left join pg_proc p on p.oid=to_regprocedure(f.signature)

  union all
  select 'trigger',t.schema_name||'.'||t.table_name||'.'||t.trigger_name,
    tr.oid is not null,
    jsonb_build_object('enabled',tr.tgenabled,'definition',
      case when tr.oid is not null then pg_get_triggerdef(tr.oid) end)
  from expected_triggers t
  left join pg_namespace n on n.nspname=t.schema_name
  left join pg_class c on c.relnamespace=n.oid and c.relname=t.table_name
  left join pg_trigger tr on tr.tgrelid=c.oid and tr.tgname=t.trigger_name
    and not tr.tgisinternal

  union all
  select 'constraint',x.schema_name||'.'||x.table_name||'.'||x.constraint_name,
    co.oid is not null,
    jsonb_build_object('validated',co.convalidated,'definition',
      case when co.oid is not null then pg_get_constraintdef(co.oid) end)
  from expected_constraints x
  left join pg_namespace n on n.nspname=x.schema_name
  left join pg_class c on c.relnamespace=n.oid and c.relname=x.table_name
  left join pg_constraint co on co.conrelid=c.oid and co.conname=x.constraint_name

  union all
  select 'policy',x.schema_name||'.'||x.table_name||'.'||x.policy_name,
    pol.policyname is not null,
    jsonb_build_object('permissive',pol.permissive,'roles',pol.roles,
      'command',pol.cmd,'using',pol.qual,'check',pol.with_check)
  from expected_policies x
  left join pg_policies pol on pol.schemaname=x.schema_name
    and pol.tablename=x.table_name and pol.policyname=x.policy_name

  union all
  select 'rls',n.nspname||'.'||c.relname,c.relrowsecurity,
    jsonb_build_object('forced',c.relforcerowsecurity,
      'anon_select',has_table_privilege('anon',c.oid,'SELECT'),
      'authenticated_select',has_table_privilege('authenticated',c.oid,'SELECT'))
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind in ('r','p') and c.relname in
    ('businesses','staff','tickets','payment_verification_evidence',
     'receipt_images','workspace_profiles','workspace_member_capabilities',
     'payment_tip_allocations','workspace_owner_identities',
     'chekmi_schema_meta')

  union all
  select 'index','public.receipt_images.receipt_images_storage_object_key_uq',
    to_regclass('public.receipt_images_storage_object_key_uq') is not null,
    jsonb_build_object('definition',(
      select pg_get_indexdef(to_regclass('public.receipt_images_storage_object_key_uq'))))

  union all
  select 'bucket','storage.buckets.receipt-evidence',b.id is not null,
    jsonb_build_object('public',b.public,'file_size_limit',b.file_size_limit,
      'allowed_mime_types',b.allowed_mime_types)
  from (select 1) v left join storage.buckets b on b.id='receipt-evidence'

  union all
  select 'schema_marker','public.chekmi_schema_meta',
    to_regclass('public.chekmi_schema_meta') is not null,
    jsonb_build_object('schema_version',(
      select schema_version from public.chekmi_schema_meta where singleton=true))
)
select kind,object_name,present,details from checks
order by kind,object_name;
