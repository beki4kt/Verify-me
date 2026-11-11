-- Extend the existing receipt archive. Legacy bytea originals remain readable;
-- new originals live in a private object bucket and are never overwritten.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('receipt-evidence', 'receipt-evidence', false, 6291456,
        array['image/jpeg','image/png'])
on conflict (id) do update set public=false, file_size_limit=6291456,
  allowed_mime_types=array['image/jpeg','image/png'];
-- Restrictive policy prevents a broad policy on another bucket from granting
-- anonymous/authenticated access to this one. The trusted service role bypasses RLS.
create policy receipt_evidence_private_clients on storage.objects
  as restrictive for all to anon,authenticated
  using (bucket_id <> 'receipt-evidence')
  with check (bucket_id <> 'receipt-evidence');

alter table public.receipt_images
  add column if not exists source_type text,
  add column if not exists storage_bucket text,
  add column if not exists storage_object_key text,
  add column if not exists storage_status text,
  add column if not exists stored_at timestamptz;
alter table public.receipt_images
  alter column image_data drop not null,
  alter column mime_type drop not null,
  alter column byte_size drop not null,
  alter column sha256 drop not null;
alter table public.receipt_images drop constraint if exists receipt_images_byte_size_check;
alter table public.receipt_images add constraint receipt_images_archive_size_check
  check (byte_size is null or byte_size between 1 and 6291456);
alter table public.receipt_images add constraint receipt_images_archive_status_check
  check (storage_status in ('missing_original','pending_upload','upload_failed','stored'));
alter table public.receipt_images add constraint receipt_images_archive_source_check
  check (source_type is null or source_type in ('camera','photo_library','legacy'));
alter table public.receipt_images add constraint receipt_images_archive_original_check
  check (storage_status <> 'stored' or
    (mime_type is not null and byte_size is not null and sha256 is not null and
     (image_data is not null or (storage_bucket='receipt-evidence' and storage_object_key is not null))));
create unique index if not exists receipt_images_storage_object_key_uq
  on public.receipt_images (storage_bucket,storage_object_key)
  where storage_object_key is not null;
update public.receipt_images set storage_status='stored', source_type='legacy',
  stored_at=created_at where image_data is not null and storage_status is null;
update public.receipt_images set storage_status='missing_original'
  where storage_status is null;
alter table public.receipt_images alter column storage_status set default 'missing_original';
alter table public.receipt_images alter column storage_status set not null;

create or replace function public.protect_archived_receipt_original()
returns trigger language plpgsql set search_path=public as $$
begin
  if tg_op='DELETE' then
    if old.storage_status='stored' then
      raise exception 'Archived receipt originals require a reviewed retention procedure' using errcode='42501';
    end if;
    return old;
  end if;
  if old.storage_status='stored' and
     (new.business_id is distinct from old.business_id or
      new.ticket_id is distinct from old.ticket_id or
      new.waiter_id is distinct from old.waiter_id or
      new.source_type is distinct from old.source_type or
      new.created_at is distinct from old.created_at or
      new.stored_at is distinct from old.stored_at or
      new.image_data is distinct from old.image_data or
      new.mime_type is distinct from old.mime_type or
      new.byte_size is distinct from old.byte_size or
      new.sha256 is distinct from old.sha256 or
      new.storage_bucket is distinct from old.storage_bucket or
      new.storage_object_key is distinct from old.storage_object_key or
      new.storage_status is distinct from old.storage_status) then
    raise exception 'Archived receipt original cannot be changed' using errcode='42501';
  end if;
  return new;
end $$;
drop trigger if exists receipt_original_immutable on public.receipt_images;
create trigger receipt_original_immutable before update or delete on public.receipt_images
for each row execute function public.protect_archived_receipt_original();

-- A reference-only verification is still a real verified payment. Keep an
-- explicit, linkable missing-original row even when no image was captured.
create or replace function public.create_missing_receipt_evidence()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.verification_evidence_id is not null and not new.receipt_image_saved then
    insert into public.receipt_images(business_id,ticket_id,waiter_id,storage_status)
    values(new.business_id,new.ticket_id,new.waiter_id,'missing_original')
    on conflict (ticket_id) do nothing;
  end if;
  return new;
end $$;
drop trigger if exists verified_ticket_missing_receipt on public.tickets;
create trigger verified_ticket_missing_receipt after insert on public.tickets
for each row execute function public.create_missing_receipt_evidence();
insert into public.receipt_images(business_id,ticket_id,waiter_id,storage_status)
select t.business_id,t.ticket_id,t.waiter_id,'missing_original'
from public.tickets t
where t.verification_evidence_id is not null
  and not exists(select 1 from public.receipt_images r where r.ticket_id=t.ticket_id);

-- The existing (business_id,provider,transaction_ref) uniqueness prevents
-- double counting inside a workspace. Also reject a new cross-workspace use
-- of a provider reference when the authoritative destination is fully known.
-- Masked destinations cannot safely prove identity and are left to the
-- existing tenant-scoped check and trusted provider verification.
create or replace function public.reject_known_cross_workspace_payment_duplicate()
returns trigger language plpgsql set search_path=public as $$
declare destination text;
begin
  if position('*' in new.receiver_account)>0 then return new; end if;
  destination:=lower(regexp_replace(new.receiver_account,'[^a-zA-Z0-9]','','g'));
  if length(destination)<6 then return new; end if;
  perform pg_advisory_xact_lock(hashtextextended(
    new.provider||':'||new.transaction_ref||':'||destination,0));
  if exists(select 1 from public.payment_verification_evidence e
    where e.provider=new.provider and e.transaction_ref=new.transaction_ref
      and e.business_id<>new.business_id and position('*' in e.receiver_account)=0
      and lower(regexp_replace(e.receiver_account,'[^a-zA-Z0-9]','','g'))=destination) then
    raise exception 'This provider transaction was already recorded'
      using errcode='23505';
  end if;
  return new;
end $$;
drop trigger if exists known_cross_workspace_payment_duplicate on public.payment_verification_evidence;
create trigger known_cross_workspace_payment_duplicate
before insert on public.payment_verification_evidence for each row
execute function public.reject_known_cross_workspace_payment_duplicate();

-- These RPCs are called only by the receipt Edge function with the service
-- role. A staff token is checked against actual tenant membership as well.
create or replace function public.reserve_receipt_original(
  p_token text,p_ticket_id uuid,p_mime_type text,p_byte_size integer,
  p_sha256 text,p_source_type text
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; t public.tickets; r public.receipt_images;
  object_key text; extension text; workspace_bytes bigint;
begin
  s:=public.require_staff_session(p_token);
  select * into t from public.tickets where ticket_id=p_ticket_id and business_id=s.business_id;
  if not found or t.verification_evidence_id is null then
    raise exception 'Verified payment not found' using errcode='42501';
  end if;
  if t.waiter_id<>s.staff_number and
     not public.staff_can(s.business_id,s.staff_number,'view_ledger') and
     not public.staff_can(s.business_id,s.staff_number,'review_payment') then
    raise exception 'Receipt access denied' using errcode='42501';
  end if;
  if p_mime_type is null or p_mime_type not in ('image/jpeg','image/png') or
     p_byte_size is null or p_byte_size not between 1 and 6291456 or
     p_sha256 is null or p_sha256 !~ '^[a-f0-9]{64}$' or
     p_source_type is null or p_source_type not in ('camera','photo_library') then
    raise exception 'Invalid original image metadata' using errcode='22023';
  end if;
  insert into public.receipt_images(business_id,ticket_id,waiter_id,storage_status)
  values(t.business_id,t.ticket_id,t.waiter_id,'missing_original')
  on conflict (ticket_id) do nothing;
  select * into r from public.receipt_images where ticket_id=p_ticket_id for update;
  if r.storage_status='stored' then
    if r.sha256=p_sha256 then
      return jsonb_build_object('status','stored','receipt_id',r.receipt_id,
        'storage_object_key',r.storage_object_key);
    end if;
    insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id)
    values(s.business_id,s.staff_number,'receipt_original_replacement_denied','ticket',p_ticket_id::text);
    return jsonb_build_object('status','replacement_denied');
  end if;
  if r.sha256 is not null and r.sha256<>p_sha256 then
    if r.storage_status<>'upload_failed' or exists(
      select 1 from storage.objects o where o.bucket_id=r.storage_bucket
        and o.name=r.storage_object_key) then
      insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id)
      values(s.business_id,s.staff_number,'receipt_retry_image_mismatch','ticket',p_ticket_id::text);
      return jsonb_build_object('status','retry_image_mismatch');
    end if;
    insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id,metadata)
    values(s.business_id,s.staff_number,'failed_receipt_upload_replaced','ticket',p_ticket_id::text,
      jsonb_build_object('previous_sha256',r.sha256,'new_sha256',p_sha256));
  end if;
  select coalesce(sum(byte_size),0) into workspace_bytes from public.receipt_images
    where business_id=s.business_id and storage_status='stored';
  if workspace_bytes+p_byte_size>2147483648 then
    raise exception 'Workspace receipt storage limit reached' using errcode='22023';
  end if;
  extension:=case when p_mime_type='image/png' then 'png' else 'jpg' end;
  object_key:=s.business_id::text||'/'||p_ticket_id::text||'/'||r.receipt_id::text||'/original.'||extension;
  update public.receipt_images set source_type=p_source_type,
    mime_type=p_mime_type,byte_size=p_byte_size,sha256=p_sha256,
    storage_bucket='receipt-evidence',storage_object_key=object_key,
    storage_status='pending_upload'
    where receipt_id=r.receipt_id;
  insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id,metadata)
  values(s.business_id,s.staff_number,'receipt_upload_reserved','ticket',p_ticket_id::text,
    jsonb_build_object('receipt_id',r.receipt_id,'sha256',p_sha256));
  return jsonb_build_object('status','pending_upload','receipt_id',r.receipt_id,
    'storage_object_key',object_key);
end $$;

create or replace function public.finish_receipt_original(p_token text,p_ticket_id uuid,p_sha256 text)
returns jsonb language plpgsql security definer set search_path=public,storage as $$
declare s public.staff_sessions; r public.receipt_images; object_size bigint;
begin
  s:=public.require_staff_session(p_token);
  select * into r from public.receipt_images
    where ticket_id=p_ticket_id and business_id=s.business_id for update;
  if not found or r.sha256<>p_sha256 or r.storage_bucket<>'receipt-evidence' or
     r.storage_status not in ('pending_upload','stored') then
    raise exception 'Receipt reservation not found' using errcode='42501';
  end if;
  if r.waiter_id<>s.staff_number and
     not public.staff_can(s.business_id,s.staff_number,'view_ledger') and
     not public.staff_can(s.business_id,s.staff_number,'review_payment') then
    raise exception 'Receipt access denied' using errcode='42501';
  end if;
  select (o.metadata->>'size')::bigint into object_size from storage.objects o
    where o.bucket_id=r.storage_bucket and o.name=r.storage_object_key;
  if not found or object_size is distinct from r.byte_size then
    raise exception 'Original image has not been confirmed in storage' using errcode='55000';
  end if;
  if r.storage_status<>'stored' then
    update public.receipt_images set storage_status='stored',stored_at=now()
      where receipt_id=r.receipt_id;
    update public.tickets set receipt_image_saved=true where ticket_id=p_ticket_id;
    insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id,metadata)
    values(s.business_id,s.staff_number,'receipt_original_stored','ticket',p_ticket_id::text,
      jsonb_build_object('receipt_id',r.receipt_id,'sha256',r.sha256));
  end if;
  return jsonb_build_object('status','stored','receipt_id',r.receipt_id);
end $$;

create or replace function public.fail_receipt_original(p_token text,p_ticket_id uuid,p_sha256 text)
returns void language plpgsql security definer set search_path=public as $$
declare s public.staff_sessions;
begin
  s:=public.require_staff_session(p_token);
  update public.receipt_images set storage_status='upload_failed'
  where ticket_id=p_ticket_id and business_id=s.business_id and sha256=p_sha256
    and (waiter_id=s.staff_number or
      public.staff_can(s.business_id,s.staff_number,'view_ledger') or
      public.staff_can(s.business_id,s.staff_number,'review_payment'))
    and storage_status='pending_upload';
  if found then
    insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id,metadata)
    values(s.business_id,s.staff_number,'receipt_upload_failed','ticket',p_ticket_id::text,
      jsonb_build_object('sha256',p_sha256));
  end if;
end $$;

-- Shared detail across all business presets. Provider payload stays server-only;
-- account numbers are masked and storage keys are never returned to clients.
create or replace function public.get_verified_receipt_detail(p_token text,p_ticket_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare s public.staff_sessions; result jsonb;
begin
  s:=public.require_staff_session(p_token);
  select jsonb_build_object(
    'ticket_id',t.ticket_id,'verification_event_id',e.evidence_id,
    'verification_status','verified','completion_status',t.status,
    'verified_amount',e.verified_amount,'expected_amount',e.expected_amount,
    'amount_difference',e.verified_amount-e.expected_amount,'currency',e.currency,
    'provider',e.provider,'transaction_reference',e.transaction_ref,
    'transaction_at',e.provider_transaction_at,'verified_at',e.created_at,
    'verified_by',e.staff_number,'reference_kind',t.reference_kind,
    'reference_value',t.reference_value,
    'receiving_account_masked',case when length(e.receiver_account)>4
      then '•••• '||right(e.receiver_account,4) else '••••' end,
    'receipt_id',r.receipt_id,'evidence_status',coalesce(r.storage_status,'missing_original'),
    'evidence_source',r.source_type,'evidence_sha256',r.sha256,
    'evidence_size',r.byte_size,'evidence_created_at',r.created_at,'evidence_stored_at',r.stored_at
  ) into result
  from public.tickets t join public.payment_verification_evidence e
    on e.evidence_id=t.verification_evidence_id and e.business_id=t.business_id
  left join public.receipt_images r on r.ticket_id=t.ticket_id and r.business_id=t.business_id
  where t.ticket_id=p_ticket_id and t.business_id=s.business_id
    and (t.waiter_id=s.staff_number or
      public.staff_can(s.business_id,s.staff_number,'view_ledger') or
      public.staff_can(s.business_id,s.staff_number,'review_payment'));
  return result;
end $$;

create or replace function public.get_receipt_image(p_token text,p_ticket_id uuid)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; r public.receipt_images;
begin
  s:=public.require_staff_session(p_token);
  select * into r from public.receipt_images
  where ticket_id=p_ticket_id and business_id=s.business_id
    and (waiter_id=s.staff_number or
      public.staff_can(s.business_id,s.staff_number,'review_payment') or
      public.staff_can(s.business_id,s.staff_number,'view_ledger'));
  if not found then return null; end if;
  return jsonb_build_object('mime_type',r.mime_type,'byte_size',r.byte_size,
    'sha256',r.sha256,'storage_status',r.storage_status,
    'image_base64',case when r.image_data is null then null
      else encode(r.image_data,'base64') end);
end $$;

create or replace function public.service_get_receipt_original_locator(p_token text,p_ticket_id uuid)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare s public.staff_sessions; r public.receipt_images;
begin
  s:=public.require_staff_session(p_token);
  select * into r from public.receipt_images
    where ticket_id=p_ticket_id and business_id=s.business_id
      and (waiter_id=s.staff_number or
        public.staff_can(s.business_id,s.staff_number,'view_ledger') or
        public.staff_can(s.business_id,s.staff_number,'review_payment'));
  if not found or r.storage_status<>'stored' then return null; end if;
  insert into public.security_audit_log(business_id,actor_staff_number,action,subject_type,subject_id)
    values(s.business_id,s.staff_number,'receipt_original_accessed','ticket',p_ticket_id::text);
  return jsonb_build_object('storage_bucket',r.storage_bucket,
    'storage_object_key',r.storage_object_key,'mime_type',r.mime_type,
    'byte_size',r.byte_size,'sha256',r.sha256,
    'legacy_image_base64',case when r.image_data is null then null
      else encode(r.image_data,'base64') end);
end $$;

revoke all on function public.reserve_receipt_original(text,uuid,text,integer,text,text) from public,anon,authenticated;
revoke all on function public.finish_receipt_original(text,uuid,text) from public,anon,authenticated;
revoke all on function public.fail_receipt_original(text,uuid,text) from public,anon,authenticated;
grant execute on function public.reserve_receipt_original(text,uuid,text,integer,text,text) to service_role;
grant execute on function public.finish_receipt_original(text,uuid,text) to service_role;
grant execute on function public.fail_receipt_original(text,uuid,text) to service_role;
revoke all on function public.service_get_receipt_original_locator(text,uuid) from public,anon,authenticated;
grant execute on function public.service_get_receipt_original_locator(text,uuid) to service_role;
grant execute on function public.get_verified_receipt_detail(text,uuid) to anon,authenticated,service_role;
grant execute on function public.get_receipt_image(text,uuid) to anon,authenticated,service_role;
