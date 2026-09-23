-- Run manually in Supabase SQL Editor only after confirming the keep email.
-- This removes all test data and all Auth users except the designated administrator.
begin;

do $$
begin
  if not exists (
    select 1
    from auth.users
    where lower(email) = lower('eptw0516@gmail.com')
  ) then
    raise exception 'KEEP_ACCOUNT_NOT_FOUND: eptw0516@gmail.com';
  end if;
end;
$$;

-- Delete dependent business data first so this remains safe with legacy FK variants.
delete from public.class_waitlists;
delete from public.bookings;
delete from public.purchase_orders;
delete from public.user_packages;
delete from public.classes;
delete from public.purchase_plans;

-- Remove application profiles except the designated administrator.
delete from public.profiles
where id not in (
  select id
  from auth.users
  where lower(email) = lower('eptw0516@gmail.com')
);

-- Remove every Auth account except the designated administrator.
delete from auth.users
where lower(email) <> lower('eptw0516@gmail.com')
   or email is null;

-- Recreate the retained profile if the previous sync never created it.
insert into public.profiles (
  id, email, full_name, phone, birth_date, line_user_id,
  role, is_instructor, is_active
)
select
  id,
  email,
  coalesce(nullif(raw_user_meta_data ->> 'full_name', ''), '管理員'),
  coalesce(nullif(raw_user_meta_data ->> 'phone', ''), ''),
  nullif(raw_user_meta_data ->> 'birth_date', '')::date,
  nullif(raw_user_meta_data ->> 'line_user_id', ''),
  'admin',
  true,
  true
from auth.users
where lower(email) = lower('eptw0516@gmail.com')
on conflict (id) do update set
  email = excluded.email,
  role = 'admin',
  is_instructor = true,
  is_active = true;

-- Ensure the retained account can administer the fresh test environment.
update public.profiles
set role = 'admin',
    is_instructor = true,
    is_active = true
where id = (
  select id
  from auth.users
  where lower(email) = lower('eptw0516@gmail.com')
);

commit;

-- Verification queries:
select id, email, role, is_instructor, is_active
from public.profiles
order by created_at;

select count(*) as remaining_auth_users
from auth.users;
