-- Read-only assertions for an existing Mesob workspace after the catch-up.
-- This file never creates staff, changes passwords, or changes bank accounts.
do $$
declare
  mesob public.businesses;
begin
  select * into mesob from public.businesses where business_code='MESOB-DEMO';
  if not found then
    raise exception 'MESOB-DEMO is absent; do not seed known credentials into this project';
  end if;
  if not public.subscription_has_access(mesob) then
    raise exception 'MESOB-DEMO subscription is not active for testing';
  end if;
  if not mesob.has_cashier_module then
    raise exception 'MESOB-DEMO cashier module is disabled';
  end if;
  if not exists (
    select 1 from jsonb_each_text(coalesce(mesob.bank_accounts,'{}'::jsonb))
      as account_field(key,value)
    where key like '%_number' and btrim(value)<>''
  ) then
    raise exception 'MESOB-DEMO has no configured receiving account';
  end if;
  if not exists (
    select 1 from public.staff
    where business_id=mesob.business_id and is_active
  ) then
    raise exception 'MESOB-DEMO has no active staff member';
  end if;
  if not exists (
    select 1 from public.workspace_profiles
    where business_id=mesob.business_id and use_case='restaurant'
  ) then
    raise exception 'MESOB-DEMO restaurant workspace profile is missing';
  end if;
  if to_regprocedure('public.request_owner_workspace(text,text,text,text,text,text,boolean,text,text,text,text)') is null or
     to_regprocedure('public.get_verified_receipt_detail(text,uuid)') is null or
     to_regprocedure('public.reserve_receipt_original(text,uuid,text,integer,text,text)') is null or
     to_regprocedure('public.finish_receipt_original(text,uuid,text)') is null or
     to_regprocedure('public.service_get_receipt_original_locator(text,uuid)') is null then
    raise exception 'Owner registration or receipt-evidence RPC is missing';
  end if;
  if not exists (
    select 1 from storage.buckets
    where id='receipt-evidence' and public=false
      and file_size_limit=6291456
  ) then
    raise exception 'Private receipt-evidence bucket is missing or misconfigured';
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname='receipt_evidence_private_clients'
      and permissive='RESTRICTIVE'
  ) then
    raise exception 'Receipt object privacy policy is missing';
  end if;
  if not has_function_privilege('service_role',
      'public.reserve_receipt_original(text,uuid,text,integer,text,text)',
      'EXECUTE') or
     has_function_privilege('anon',
      'public.reserve_receipt_original(text,uuid,text,integer,text,text)',
      'EXECUTE') then
    raise exception 'Receipt reservation RPC grants are incorrect';
  end if;
end $$;

select b.business_code,b.subscription_tier,b.subscription_status,
  b.has_cashier_module,wp.use_case,wp.review_policy,
  (select count(*) from public.staff s
   where s.business_id=b.business_id and s.is_active) as active_staff,
  (select count(*) from jsonb_object_keys(coalesce(b.bank_accounts,'{}'::jsonb))
    as account_key(key) where key like '%_number')
    as configured_receiving_account_fields
from public.businesses b
join public.workspace_profiles wp on wp.business_id=b.business_id
where b.business_code='MESOB-DEMO';
