-- Let a signed-in restaurant administrator rotate their own password without
-- exposing the staff table to the anonymous Supabase client.

create or replace function public.change_current_admin_password(
  p_token text,
  p_current_password text,
  p_new_password text
) returns void
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  s public.staff_sessions;
  current_staff public.staff;
begin
  s:=public.require_staff_session(p_token);

  select st.* into current_staff
  from public.staff st
  where st.business_id=s.business_id
    and st.staff_number=s.staff_number
    and st.is_active
  limit 1;

  if not found or s.role <> 'admin' or current_staff.role <> 'admin' then
    raise exception 'Only an administrator can change this password'
      using errcode='42501';
  end if;

  if p_current_password is null or not (
    (current_staff.password_hash is not null and
      extensions.crypt(p_current_password,current_staff.password_hash)=current_staff.password_hash)
    or
    (current_staff.password_hash is null and current_staff.password=p_current_password)
  ) then
    raise exception 'Current password is incorrect' using errcode='P0001';
  end if;

  if p_new_password is null or length(p_new_password) < 8 then
    raise exception 'New password must be at least 8 characters long'
      using errcode='22023';
  end if;

  if p_new_password=p_current_password then
    raise exception 'New password must be different from the current password'
      using errcode='22023';
  end if;

  -- The existing staff_hash_password trigger hashes this value and clears the
  -- legacy plaintext column before the row is written.
  update public.staff
  set password=p_new_password
  where business_id=s.business_id and staff_number=s.staff_number;

  -- Keep the session that authorized the rotation, but revoke every other
  -- session for this administrator so other devices must authenticate again.
  update public.staff_sessions
  set revoked_at=now()
  where business_id=s.business_id
    and staff_number=s.staff_number
    and session_id<>s.session_id
    and revoked_at is null;
end $$;

revoke all on function public.change_current_admin_password(text,text,text) from public;
grant execute on function public.change_current_admin_password(text,text,text) to anon,authenticated;
