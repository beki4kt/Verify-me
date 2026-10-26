-- Read-only follow-up for migration history reconciliation.
-- Reports only missing/unsafe objects, plus a checked/failed count per kind.
-- No customer rows, receipt contents, or credentials are read.
with
expected_triggers(schema_name,table_name,trigger_name) as (values
  ('public','staff','staff_hash_password'),
  ('public','payment_verification_evidence','payment_evidence_immutable'),
  ('public','ticket_financial_events','ticket_financial_events_immutable'),
  ('public','tickets','tickets_protect_verified_values'),
  ('public','tip_payout_ledger','tip_payout_ledger_immutable')
),
expected_indexes(index_name) as (values
  ('tickets_provider_reference_unique'),
  ('payment_evidence_business_created_idx'),
  ('receipt_images_business_created_idx'),
  ('tip_withdrawals_business_status_idx'),
  ('tip_withdrawals_waiter_idx'),
  ('verification_attempts_staff_created_idx'),
  ('operator_audit_created_idx'),
  ('client_error_events_occurred_at_idx'),
  ('ticket_financial_events_ticket_idx'),
  ('security_audit_business_created_idx'),
  ('subscription_invoices_business_idx')
),
expected_constraints(schema_name,table_name,constraint_name,expected_validated) as (values
  ('public','tip_withdrawal_requests','tip_withdrawal_requests_status_check',true),
  -- The payment-correctness migration deliberately adds this as NOT VALID.
  ('public','payment_verification_evidence','payment_evidence_provider_date_required',false),
  ('public','tickets','tickets_verification_evidence_fk',true)
),
checks as (
  select 'trigger'::text kind,t.schema_name||'.'||t.table_name||'.'||t.trigger_name object_name,
    tr.oid is not null and tr.tgenabled='O' as ok
  from expected_triggers t
  left join pg_namespace n on n.nspname=t.schema_name
  left join pg_class c on c.relnamespace=n.oid and c.relname=t.table_name
  left join pg_trigger tr on tr.tgrelid=c.oid and tr.tgname=t.trigger_name
    and not tr.tgisinternal

  union all
  select 'index', 'public.'||i.index_name,
    to_regclass('public.'||i.index_name) is not null
  from expected_indexes i

  union all
  select 'constraint',x.schema_name||'.'||x.table_name||'.'||x.constraint_name,
    co.oid is not null and co.convalidated=x.expected_validated
  from expected_constraints x
  left join pg_namespace n on n.nspname=x.schema_name
  left join pg_class c on c.relnamespace=n.oid and c.relname=x.table_name
  left join pg_constraint co on co.conrelid=c.oid and co.conname=x.constraint_name

  union all
  select 'table_access',n.nspname||'.'||c.relname,
    c.relrowsecurity and not has_table_privilege('anon',c.oid,'SELECT')
      and not has_table_privilege('authenticated',c.oid,'SELECT')
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind in ('r','p')
    and c.relname<>'legal_documents'
)
select kind, object_name, ok
from checks where ok is distinct from true
union all
select 'summary',kind||': '||count(*)||' checked, '
  ||count(*) filter (where ok is distinct from true)||' failed',true
from checks group by kind
order by kind,object_name;
