-- Ticket access is authenticated with the opaque token issued by login_staff.
-- Direct anon/authenticated table access cannot safely enforce tenant identity
-- because Verify-Me uses its own staff sessions rather than Supabase Auth JWTs.

create or replace function public.require_staff_session(p_token text)
returns public.staff_sessions
language plpgsql
security definer
set search_path=public,extensions
as $$
declare s public.staff_sessions;
begin
  if p_token is null or length(p_token) < 32 then
    raise exception 'Invalid or expired staff session' using errcode='28000';
  end if;

  select ss.* into s
  from public.staff_sessions ss
  join public.businesses b on b.business_id=ss.business_id
  join public.staff st on st.business_id=ss.business_id and st.staff_number=ss.staff_number
  where ss.token_hash=extensions.digest(convert_to(p_token,'UTF8'),'sha256')
    and ss.revoked_at is null and ss.expires_at > now()
    and b.is_active and st.is_active;

  if not found then
    raise exception 'Invalid or expired staff session' using errcode='28000';
  end if;
  return s;
end $$;
revoke all on function public.require_staff_session(text) from public;

create or replace function public.create_ticket(
  p_token text, p_transaction_ref text, p_bill_amount numeric,
  p_bank text, p_table_number text, p_tip_amount numeric default 0
) returns public.tickets
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; created public.tickets;
begin
  s:=public.require_staff_session(p_token);
  if s.role not in ('waiter','admin') then
    raise exception 'Role is not allowed to create tickets' using errcode='42501';
  end if;
  if btrim(coalesce(p_table_number,''))='' then
    raise exception 'Table number is required' using errcode='22023';
  end if;
  if p_bill_amount is null or p_bill_amount <= 0 then
    raise exception 'Bill amount must be positive' using errcode='22023';
  end if;
  insert into public.tickets(
    business_id,waiter_id,table_number,transaction_ref,bill_amount,tip_amount,bank,status
  ) values (
    s.business_id,s.staff_number,btrim(p_table_number),upper(btrim(p_transaction_ref)),
    p_bill_amount,greatest(coalesce(p_tip_amount,0),0),btrim(p_bank),'pending'
  ) returning * into created;
  return created;
end $$;

create or replace function public.list_tickets(p_token text, p_scope text default 'business')
returns setof public.tickets
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if p_scope='waiter' then
    return query select t.* from public.tickets t
      where t.business_id=s.business_id and t.waiter_id=s.staff_number
      order by t.created_at desc limit 100;
  end if;
  if s.role not in ('cashier','admin') then
    raise exception 'Role is not allowed to view the business ledger' using errcode='42501';
  end if;
  return query select t.* from public.tickets t
    where t.business_id=s.business_id order by t.created_at desc limit 100;
end $$;

create or replace function public.transition_ticket(
  p_token text, p_ticket_id uuid, p_status text,
  p_actual_amount numeric default null, p_tip_amount numeric default null
) returns public.tickets
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; changed public.tickets;
begin
  s:=public.require_staff_session(p_token);
  if s.role not in ('cashier','admin') then
    raise exception 'Role is not allowed to transition tickets' using errcode='42501';
  end if;
  if p_status not in ('settled','rejected') then
    raise exception 'Invalid ticket transition' using errcode='22023';
  end if;
  update public.tickets set
    status=p_status,
    actual_amount=case when p_status='settled' then p_actual_amount else actual_amount end,
    tip_amount=case when p_status='settled' then greatest(coalesce(p_tip_amount,0),0) else tip_amount end,
    updated_at=now()
  where ticket_id=p_ticket_id and business_id=s.business_id and status='pending'
  returning * into changed;
  if not found then
    raise exception 'Pending ticket not found' using errcode='P0002';
  end if;
  return changed;
end $$;

create or replace function public.logout_staff(p_token text)
returns void language plpgsql security definer set search_path=public,extensions as $$
begin
  update public.staff_sessions set revoked_at=now()
  where token_hash=extensions.digest(convert_to(p_token,'UTF8'),'sha256') and revoked_at is null;
end $$;

revoke all on function public.create_ticket(text,text,numeric,text,text,numeric) from public;
revoke all on function public.list_tickets(text,text) from public;
revoke all on function public.transition_ticket(text,uuid,text,numeric,numeric) from public;
revoke all on function public.logout_staff(text) from public;
grant execute on function public.create_ticket(text,text,numeric,text,text,numeric) to anon,authenticated;
grant execute on function public.list_tickets(text,text) to anon,authenticated;
grant execute on function public.transition_ticket(text,uuid,text,numeric,numeric) to anon,authenticated;
grant execute on function public.logout_staff(text) to anon,authenticated;

drop policy if exists tickets_insert_active_business on public.tickets;
drop policy if exists tickets_select_active_business on public.tickets;
drop policy if exists tickets_update_active_business on public.tickets;
revoke all on public.tickets from anon,authenticated;
