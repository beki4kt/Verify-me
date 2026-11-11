-- Local Supabase only. Uses the known credentials from seed.sql.
-- Never run against the configured live project.
do $$
declare
  mesob_id uuid;
  session_result jsonb;
  profile_result jsonb;
begin
  select business_id into mesob_id from public.businesses
  where business_code='MESOB-DEMO';
  if mesob_id is null then raise exception 'Mesob seed is missing'; end if;

  session_result:=public.login_staff(mesob_id,'+251911000003','WaiterTest!2026');
  if session_result is null or nullif(session_result->>'token','') is null then
    raise exception 'Seeded Mesob waiter cannot sign in';
  end if;
  profile_result:=public.get_workspace_profile(session_result->>'token');
  if profile_result->>'use_case'<>'restaurant' then
    raise exception 'Mesob login did not resolve its restaurant profile';
  end if;
  if public.get_verified_receipt_detail(
       session_result->>'token','00000000-0000-0000-0000-000000000000'::uuid
     ) is not null then
    raise exception 'Unknown receipt unexpectedly returned data';
  end if;
end $$;
