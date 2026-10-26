-- Read-only detail for the exact failures in master_schema_remaining_checks.sql.
-- It reads catalog metadata only, never session rows or financial records.
select 'constraint'::text as kind,
  'public.payment_verification_evidence.payment_evidence_provider_date_required' as object_name,
  jsonb_build_object(
    'exists',co.oid is not null,
    'validated',co.convalidated,
    'definition',case when co.oid is not null then pg_get_constraintdef(co.oid) end
  ) as details
from (select 1) anchor
left join pg_constraint co on co.conrelid='public.payment_verification_evidence'::regclass
  and co.conname='payment_evidence_provider_date_required'

union all

select 'table_access', 'public.'||c.relname,
  jsonb_build_object(
    'rls_enabled',c.relrowsecurity,
    'rls_forced',c.relforcerowsecurity,
    'anon_select',has_table_privilege('anon',c.oid,'SELECT'),
    'authenticated_select',has_table_privilege('authenticated',c.oid,'SELECT'),
    'anon_insert',has_table_privilege('anon',c.oid,'INSERT'),
    'authenticated_insert',has_table_privilege('authenticated',c.oid,'INSERT'),
    'anon_update',has_table_privilege('anon',c.oid,'UPDATE'),
    'authenticated_update',has_table_privilege('authenticated',c.oid,'UPDATE'),
    'anon_delete',has_table_privilege('anon',c.oid,'DELETE'),
    'authenticated_delete',has_table_privilege('authenticated',c.oid,'DELETE'),
    'policies',(select count(*) from pg_policies p
      where p.schemaname='public' and p.tablename=c.relname)
  )
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind in ('r','p')
  and c.relname in ('app_sessions','staff_sessions','super_admins',
    'ticket_audit_logs','verified_transactions')
order by kind,object_name;
