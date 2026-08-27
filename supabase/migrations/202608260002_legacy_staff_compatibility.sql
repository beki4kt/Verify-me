-- Schema marker for the legacy-staff compatibility bootstrap. The actual
-- normalization runs in base_schema.sql before functions and constraints are
-- installed, allowing the one-shot bundle to upgrade the original pilot.

insert into public.chekmi_schema_meta(singleton,schema_version,applied_at)
values(true,'2026-08-26.2',now())
on conflict(singleton) do update set
  schema_version=excluded.schema_version,
  applied_at=excluded.applied_at;

notify pgrst,'reload schema';
