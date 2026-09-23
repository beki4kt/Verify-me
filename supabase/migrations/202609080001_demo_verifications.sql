-- Demo receipts never enter business tickets or staff sessions.
create table if not exists public.demo_installations (
  token_hash text primary key check (token_hash ~ '^[0-9a-f]{64}$'),
  used integer not null default 0 check (used between 0 and 10),
  created_at timestamptz not null default now()
);
create table if not exists public.demo_lookup_requests (
  token_hash text not null references public.demo_installations(token_hash),
  request_id uuid not null,
  fingerprint text not null,
  result jsonb,
  created_at timestamptz not null default now(),
  primary key (token_hash, request_id)
);
create table if not exists public.demo_daily_usage (
  day date primary key,
  used integer not null default 0 check (used >= 0)
);
alter table public.demo_installations enable row level security;
alter table public.demo_lookup_requests enable row level security;
alter table public.demo_daily_usage enable row level security;
revoke all on public.demo_installations, public.demo_lookup_requests, public.demo_daily_usage from public, anon, authenticated;

create or replace function public.demo_lookup_status(p_token_hash text, p_request_id uuid default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare count_used integer; saved jsonb;
begin
  select used into count_used from public.demo_installations where token_hash=p_token_hash;
  if p_request_id is not null then
    select result into saved from public.demo_lookup_requests where token_hash=p_token_hash and request_id=p_request_id;
  end if;
  return jsonb_build_object('remaining',10-coalesce(count_used,0),'result',saved);
end $$;

create or replace function public.reserve_demo_lookup(p_token_hash text,p_request_id uuid,p_fingerprint text,p_daily_limit integer)
returns jsonb language plpgsql security definer set search_path=public as $$
declare count_used integer; daily_used integer; old_request public.demo_lookup_requests; today date := (now() at time zone 'UTC')::date;
begin
  if p_daily_limit is null or p_daily_limit < 1 or p_daily_limit > 10000 or p_fingerprint !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid demo reservation' using errcode='22023';
  end if;
  insert into public.demo_installations(token_hash) values(p_token_hash) on conflict do nothing;
  select used into count_used from public.demo_installations where token_hash=p_token_hash for update;
  select * into old_request from public.demo_lookup_requests where token_hash=p_token_hash and request_id=p_request_id;
  if found then
    if old_request.fingerprint <> p_fingerprint then
      return jsonb_build_object('state','conflict','remaining',10-count_used);
    end if;
    return jsonb_build_object('state','existing','remaining',10-count_used,'result',old_request.result);
  end if;
  if count_used>=10 then return jsonb_build_object('state','exhausted','remaining',0); end if;
  insert into public.demo_daily_usage(day) values(today) on conflict do nothing;
  select used into daily_used from public.demo_daily_usage where day=today for update;
  if daily_used>=p_daily_limit then return jsonb_build_object('state','capacity','remaining',10-count_used); end if;
  update public.demo_installations set used=used+1 where token_hash=p_token_hash;
  update public.demo_daily_usage set used=used+1 where day=today;
  insert into public.demo_lookup_requests(token_hash,request_id,fingerprint) values(p_token_hash,p_request_id,p_fingerprint);
  return jsonb_build_object('state','reserved','remaining',9-count_used);
end $$;

create or replace function public.finish_demo_lookup(p_token_hash text,p_request_id uuid,p_result jsonb)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.demo_lookup_requests set result=p_result
    where token_hash=p_token_hash and request_id=p_request_id and result is null;
  if not found then raise exception 'Demo result could not be saved' using errcode='P0002'; end if;
end $$;
revoke all on function public.demo_lookup_status(text,uuid), public.reserve_demo_lookup(text,uuid,text,integer), public.finish_demo_lookup(text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.demo_lookup_status(text,uuid), public.reserve_demo_lookup(text,uuid,text,integer), public.finish_demo_lookup(text,uuid,jsonb) to service_role;
