-- Staging only. The password is supplied by psql -v fixture_password=... .
-- This fixture exists solely to test membership and receipt isolation.
with workspace as (
  insert into public.businesses(
    name,business_code,subscription_tier,max_staff_limit,
    has_cashier_module,is_active,bank_accounts
  ) values (
    'CHEKMI Synthetic Isolation B','ISOLATION-DEMO-B','pro',3,true,true,
    jsonb_build_object('telebirr_number','+251911000098',
                       'telebirr_name','CHEKMI Synthetic Isolation B')
  )
  on conflict (business_code) do update set name=excluded.name,
    bank_accounts=excluded.bank_accounts,has_cashier_module=true,is_active=true
  returning business_id
)
insert into public.staff(staff_number,business_id,name,phone_number,password,
                         password_hash,role,is_active)
select '9004',business_id,'Synthetic Isolation B Member','+251911000004',null,
       extensions.crypt(:'fixture_password',extensions.gen_salt('bf')),
       'cashier',true
from workspace
on conflict (business_id,staff_number) do update set
  business_id=excluded.business_id,name=excluded.name,
  phone_number=excluded.phone_number,password=null,
  password_hash=excluded.password_hash,role=excluded.role,is_active=true;
