-- NON-PRODUCTION DATA ONLY.
-- Run this file explicitly after migrations in local or staging environments.
-- Production migrations intentionally do not create known demo credentials.

do $$ declare demo_business uuid; demo record; begin
  insert into public.businesses(
    name,business_code,subscription_tier,max_staff_limit,
    has_cashier_module,is_active,bank_accounts
  ) values (
    'Mesob Demo Restaurant','MESOB-DEMO','pro',20,true,true,
    jsonb_build_object(
      'telebirr_number','+251911000099',
      'telebirr_name','Mesob Demo Restaurant',
      'cbe_number','1000000000000999',
      'cbe_name','Mesob Demo Restaurant',
      'cbebirr_number','+251911000099',
      'cbebirr_name','Mesob Demo Restaurant',
      'dashen_number','2000000000000999',
      'dashen_name','Mesob Demo Restaurant',
      'abyssinia_number','3000000000000999',
      'abyssinia_name','Mesob Demo Restaurant',
      'mpesa_number','+251711000099',
      'mpesa_name','Mesob Demo Restaurant'
    )
  )
  on conflict (business_code) do update set
    name=excluded.name,
    subscription_tier=excluded.subscription_tier,
    max_staff_limit=excluded.max_staff_limit,
    has_cashier_module=true,
    is_active=true,
    bank_accounts=excluded.bank_accounts
  returning business_id into demo_business;

  for demo in
    select * from (values
      ('1001','Demo Admin','+251911000001','AdminTest!2026','admin'),
      ('1002','Demo Cashier','+251911000002','CashierTest!2026','cashier'),
      ('1003','Demo Waiter','+251911000003','WaiterTest!2026','waiter')
    ) as d(staff_number,name,phone_number,plain_password,role)
  loop
    update public.staff set
      business_id=demo_business,
      name=demo.name,
      password=null,
      password_hash=extensions.crypt(demo.plain_password,extensions.gen_salt('bf')),
      role=demo.role,
      is_active=true
    where phone_number=demo.phone_number;

    if not found then
      update public.staff set
        business_id=demo_business,
        name=demo.name,
        phone_number=demo.phone_number,
        password=null,
        password_hash=extensions.crypt(demo.plain_password,extensions.gen_salt('bf')),
        role=demo.role,
        is_active=true
      where staff_number=demo.staff_number;
    end if;

    if not found then
      insert into public.staff(
        staff_number,business_id,name,phone_number,password,password_hash,role,is_active
      ) values (
        demo.staff_number,demo_business,demo.name,demo.phone_number,null,
        extensions.crypt(demo.plain_password,extensions.gen_salt('bf')),demo.role,true
      );
    end if;
  end loop;
end $$;
