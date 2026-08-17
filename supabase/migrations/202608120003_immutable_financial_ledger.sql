-- Immutable verified values, auditable ticket transitions, tip payout ledger,
-- and unbounded server-side filtered reporting.

alter table public.tickets
  add column if not exists settled_by text,
  add column if not exists settled_at timestamptz,
  add column if not exists rejected_by text,
  add column if not exists rejected_at timestamptz,
  add column if not exists status_reason text,
  add column if not exists financial_state text not null default 'normal';

create table if not exists public.ticket_financial_events (
  event_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  ticket_id uuid not null references public.tickets(ticket_id) on delete cascade,
  actor_staff_number text not null,
  action text not null check (action in ('settled','rejected','voided','refunded','disputed')),
  previous_status text,
  new_status text,
  reason text not null check (length(btrim(reason)) between 3 and 500),
  amount numeric,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists ticket_financial_events_ticket_idx
  on public.ticket_financial_events (business_id,ticket_id,created_at desc);
alter table public.ticket_financial_events enable row level security;
revoke all on public.ticket_financial_events from anon,authenticated;

create or replace function public.prevent_financial_evidence_mutation() returns trigger
language plpgsql set search_path=public as $$
begin
  raise exception 'Financial evidence is immutable' using errcode='55000';
end $$;
drop trigger if exists payment_evidence_immutable on public.payment_verification_evidence;
create trigger payment_evidence_immutable before update or delete
  on public.payment_verification_evidence for each row
  execute function public.prevent_financial_evidence_mutation();
drop trigger if exists ticket_financial_events_immutable on public.ticket_financial_events;
create trigger ticket_financial_events_immutable before update or delete
  on public.ticket_financial_events for each row
  execute function public.prevent_financial_evidence_mutation();

create or replace function public.protect_verified_ticket_values() returns trigger
language plpgsql set search_path=public as $$
begin
  if old.verification_evidence_id is not null and (
    new.business_id is distinct from old.business_id or
    new.waiter_id is distinct from old.waiter_id or
    new.transaction_ref is distinct from old.transaction_ref or
    new.bank is distinct from old.bank or
    new.bill_amount is distinct from old.bill_amount or
    new.expected_amount is distinct from old.expected_amount or
    new.verified_amount is distinct from old.verified_amount or
    new.tip_amount is distinct from old.tip_amount or
    new.provider_transaction_at is distinct from old.provider_transaction_at or
    new.payer_name is distinct from old.payer_name or
    new.payer_account is distinct from old.payer_account or
    new.receiver_name is distinct from old.receiver_name or
    new.receiver_account is distinct from old.receiver_account or
    new.verification_evidence_id is distinct from old.verification_evidence_id
  ) then
    raise exception 'Verified payment values cannot be changed' using errcode='55000';
  end if;
  return new;
end $$;
drop trigger if exists tickets_protect_verified_values on public.tickets;
create trigger tickets_protect_verified_values before update on public.tickets
  for each row execute function public.protect_verified_ticket_values();

create or replace function public.transition_verified_ticket(
  p_token text,p_ticket_id uuid,p_status text,p_reason text
) returns public.tickets
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; current_ticket public.tickets; changed public.tickets; reason text;
begin
  s:=public.require_staff_session(p_token);
  if s.role not in ('cashier','admin') then
    raise exception 'Cashier or administrator role required' using errcode='42501';
  end if;
  if p_status not in ('settled','rejected') then
    raise exception 'Invalid ticket transition' using errcode='22023';
  end if;
  reason:=btrim(coalesce(p_reason,''));
  if length(reason)<3 then raise exception 'A reason is required' using errcode='22023'; end if;
  select * into current_ticket from public.tickets
    where ticket_id=p_ticket_id and business_id=s.business_id and status='pending'
    for update;
  if not found then raise exception 'Pending ticket not found' using errcode='P0002'; end if;
  if current_ticket.verification_evidence_id is null or current_ticket.verified_amount is null then
    raise exception 'Ticket has no authoritative verification evidence' using errcode='55000';
  end if;

  update public.tickets set
    status=p_status,
    actual_amount=case when p_status='settled' then verified_amount else actual_amount end,
    settled_by=case when p_status='settled' then s.staff_number else settled_by end,
    settled_at=case when p_status='settled' then now() else settled_at end,
    rejected_by=case when p_status='rejected' then s.staff_number else rejected_by end,
    rejected_at=case when p_status='rejected' then now() else rejected_at end,
    status_reason=reason,updated_at=now()
  where ticket_id=p_ticket_id returning * into changed;

  insert into public.ticket_financial_events(
    business_id,ticket_id,actor_staff_number,action,previous_status,new_status,reason,amount
  ) values (
    s.business_id,p_ticket_id,s.staff_number,p_status,current_ticket.status,p_status,reason,
    case when p_status='settled' then current_ticket.verified_amount else null end
  );
  return changed;
end $$;

create or replace function public.record_ticket_financial_action(
  p_token text,p_ticket_id uuid,p_action text,p_reason text
) returns void
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; ticket public.tickets; next_state text; reason text;
begin
  s:=public.require_staff_session(p_token);
  if s.role<>'admin' then raise exception 'Administrator role required' using errcode='42501'; end if;
  if p_action not in ('voided','refunded','disputed') then raise exception 'Invalid financial action' using errcode='22023'; end if;
  reason:=btrim(coalesce(p_reason,''));
  if length(reason)<3 then raise exception 'A reason is required' using errcode='22023'; end if;
  select * into ticket from public.tickets where ticket_id=p_ticket_id and business_id=s.business_id for update;
  if not found then raise exception 'Ticket not found' using errcode='P0002'; end if;
  next_state:=p_action;
  update public.tickets set financial_state=next_state,updated_at=now() where ticket_id=p_ticket_id;
  insert into public.ticket_financial_events(
    business_id,ticket_id,actor_staff_number,action,previous_status,new_status,reason,amount
  ) values (
    s.business_id,p_ticket_id,s.staff_number,p_action,ticket.financial_state,next_state,reason,
    ticket.verified_amount
  );
end $$;

create or replace function public.list_ticket_report(
  p_token text,p_from timestamptz default null,p_to timestamptz default null,
  p_staff_number text default null,p_provider text default null
) returns setof public.tickets
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  if s.role not in ('cashier','admin') then raise exception 'Business ledger role required' using errcode='42501'; end if;
  return query select t.* from public.tickets t
  where t.business_id=s.business_id
    and (p_from is null or t.created_at>=p_from)
    and (p_to is null or t.created_at<p_to)
    and (nullif(btrim(p_staff_number),'') is null or t.waiter_id=p_staff_number)
    and (nullif(lower(btrim(p_provider)),'') is null or lower(t.bank)=lower(btrim(p_provider)))
  order by t.created_at desc;
end $$;

alter table public.tip_withdrawal_requests
  add column if not exists paid_at timestamptz,
  add column if not exists paid_by text;
alter table public.tip_withdrawal_requests
  drop constraint if exists tip_withdrawal_requests_status_check;
alter table public.tip_withdrawal_requests
  add constraint tip_withdrawal_requests_status_check
  check (status in ('pending','approved','rejected','paid'));

create table if not exists public.tip_payout_ledger (
  payout_event_id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(business_id) on delete cascade,
  request_id uuid not null references public.tip_withdrawal_requests(request_id) on delete restrict,
  staff_number text not null,
  actor_staff_number text not null,
  action text not null check (action in ('approved','rejected','paid')),
  amount numeric not null check (amount>0),
  created_at timestamptz not null default now()
);
alter table public.tip_payout_ledger enable row level security;
revoke all on public.tip_payout_ledger from anon,authenticated;
drop trigger if exists tip_payout_ledger_immutable on public.tip_payout_ledger;
create trigger tip_payout_ledger_immutable before update or delete on public.tip_payout_ledger
  for each row execute function public.prevent_financial_evidence_mutation();

create or replace function public.request_tip_withdrawal(p_token text,p_amount numeric)
returns public.tip_withdrawal_requests
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; earned numeric; committed numeric; created public.tip_withdrawal_requests;
begin
  s:=public.require_staff_session(p_token);
  if s.role<>'waiter' then raise exception 'Only waiters can request tip withdrawals' using errcode='42501'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Withdrawal amount must be positive' using errcode='22023'; end if;
  select coalesce(sum(t.tip_amount),0) into earned from public.tickets t
    where t.business_id=s.business_id and t.waiter_id=s.staff_number and t.status='settled';
  select coalesce(sum(w.amount),0) into committed from public.tip_withdrawal_requests w
    where w.business_id=s.business_id and w.staff_number=s.staff_number
      and w.status in ('pending','approved','paid');
  if p_amount>earned-committed then raise exception 'Withdrawal amount exceeds available tip balance' using errcode='22023'; end if;
  insert into public.tip_withdrawal_requests(business_id,staff_number,amount)
  values(s.business_id,s.staff_number,p_amount) returning * into created;
  return created;
end $$;

create or replace function public.resolve_tip_withdrawal_request(
  p_token text,p_request_id uuid,p_status text
) returns public.tip_withdrawal_requests
language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; current_request public.tip_withdrawal_requests; changed public.tip_withdrawal_requests;
begin
  s:=public.require_staff_session(p_token);
  if s.role<>'admin' then raise exception 'Only an administrator can resolve withdrawals' using errcode='42501'; end if;
  select * into current_request from public.tip_withdrawal_requests
    where request_id=p_request_id and business_id=s.business_id for update;
  if not found then raise exception 'Withdrawal request not found' using errcode='P0002'; end if;
  if not ((current_request.status='pending' and p_status in ('approved','rejected')) or
          (current_request.status='approved' and p_status='paid')) then
    raise exception 'Invalid withdrawal transition' using errcode='22023';
  end if;
  update public.tip_withdrawal_requests set status=p_status,
    resolved_at=case when p_status in ('approved','rejected') then now() else resolved_at end,
    resolved_by=case when p_status in ('approved','rejected') then s.staff_number else resolved_by end,
    paid_at=case when p_status='paid' then now() else paid_at end,
    paid_by=case when p_status='paid' then s.staff_number else paid_by end
  where request_id=p_request_id returning * into changed;
  insert into public.tip_payout_ledger(business_id,request_id,staff_number,actor_staff_number,action,amount)
  values(s.business_id,p_request_id,current_request.staff_number,s.staff_number,p_status,current_request.amount);
  return changed;
end $$;

revoke all on function public.transition_ticket(text,uuid,text,numeric,numeric) from public,anon,authenticated;
revoke all on function public.transition_verified_ticket(text,uuid,text,text) from public;
revoke all on function public.record_ticket_financial_action(text,uuid,text,text) from public;
revoke all on function public.list_ticket_report(text,timestamptz,timestamptz,text,text) from public;
grant execute on function public.transition_verified_ticket(text,uuid,text,text) to anon,authenticated;
grant execute on function public.record_ticket_financial_action(text,uuid,text,text) to anon,authenticated;
grant execute on function public.list_ticket_report(text,timestamptz,timestamptz,text,text) to anon,authenticated;
