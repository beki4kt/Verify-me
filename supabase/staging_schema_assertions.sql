-- Read-only staging schema assertions. Run after migrations and before seeding.
do $$
declare missing text;
begin
  select string_agg(name, ', ') into missing from (
    select unnest(array['workspace_profiles','workspace_member_capabilities',
      'payment_verification_evidence','receipt_images','tickets']) as name
  ) expected where to_regclass('public.' || name) is null;
  if missing is not null then
    raise exception 'Required public tables missing: %', missing;
  end if;

  if not exists (select 1 from storage.buckets where id='receipt-evidence'
      and public=false and file_size_limit=6291456
      and allowed_mime_types @> array['image/jpeg','image/png']) then
    raise exception 'Private receipt-evidence bucket or upload limits are missing';
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage'
      and tablename='objects' and policyname='receipt_evidence_private_clients'
      and permissive='RESTRICTIVE') then
    raise exception 'Receipt evidence storage-deny policy is missing';
  end if;
  if not exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname='receipt_images' and c.relrowsecurity) then
    raise exception 'Receipt images RLS is disabled';
  end if;
  if to_regprocedure('public.reserve_receipt_original(text,uuid,text,integer,text,text)') is null or
     to_regprocedure('public.finish_receipt_original(text,uuid,text)') is null or
     to_regprocedure('public.service_get_receipt_original_locator(text,uuid)') is null or
     to_regprocedure('public.get_verified_receipt_detail(text,uuid)') is null then
    raise exception 'Receipt archive RPC signature mismatch';
  end if;
  if has_function_privilege('anon', 'public.reserve_receipt_original(text,uuid,text,integer,text,text)', 'EXECUTE') or
     has_function_privilege('authenticated', 'public.reserve_receipt_original(text,uuid,text,integer,text,text)', 'EXECUTE') or
     has_function_privilege('anon', 'public.service_get_receipt_original_locator(text,uuid)', 'EXECUTE') or
     has_function_privilege('authenticated', 'public.service_get_receipt_original_locator(text,uuid)', 'EXECUTE') then
    raise exception 'Service-only receipt RPC is callable by a client role';
  end if;
end $$;
