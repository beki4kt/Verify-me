-- Waiter wallet totals and receipt history must include the staff member's
-- complete verified history. Keep the broader business ledger bounded.
create or replace function public.list_tickets(p_token text, p_scope text default 'business')
returns setof public.tickets
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if p_scope='waiter' then
    return query select t.* from public.tickets t
      where t.business_id=s.business_id and t.waiter_id=s.staff_number
      order by t.created_at desc;
  end if;
  if s.role not in ('cashier','admin') then
    raise exception 'Role is not allowed to view the business ledger' using errcode='42501';
  end if;
  return query select t.* from public.tickets t
    where t.business_id=s.business_id order by t.created_at desc limit 100;
end $$;

revoke all on function public.list_tickets(text,text) from public;
grant execute on function public.list_tickets(text,text) to anon,authenticated;
