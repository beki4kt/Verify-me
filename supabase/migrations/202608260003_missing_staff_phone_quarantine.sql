-- The original pilot allowed staff without phone numbers, while current
-- authentication requires a tenant-scoped phone. Preserve those rows but keep
-- their generated placeholders from becoming active login identifiers.

update public.staff
set is_active=false
where phone_number like 'legacy-unset-%';

insert into public.chekmi_schema_meta(singleton,schema_version,applied_at)
values(true,'2026-08-26.3',now())
on conflict(singleton) do update set
  schema_version=excluded.schema_version,
  applied_at=excluded.applied_at;

notify pgrst,'reload schema';
