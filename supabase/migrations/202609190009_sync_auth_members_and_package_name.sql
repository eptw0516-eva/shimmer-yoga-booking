-- Sync Auth users into the member-management table and repair legacy package_name.
-- Safe to run repeatedly.

alter table public.profiles
  add column if not exists email text;

update public.profiles p
set email = u.email
from auth.users u
where p.id = u.id
  and (p.email is null or p.email = '');

insert into public.profiles (id, email, full_name, phone, line_user_id, birth_date, is_instructor, is_active)
select
  u.id,
  u.email,
  coalesce(nullif(u.raw_user_meta_data ->> 'full_name', ''), split_part(coalesce(u.email, ''), '@', 1), '會員'),
  coalesce(nullif(u.raw_user_meta_data ->> 'phone', ''), '待補電話'),
  nullif(u.raw_user_meta_data ->> 'line_user_id', ''),
  nullif(u.raw_user_meta_data ->> 'birth_date', '')::date,
  false,
  true
from auth.users u
where not exists (
  select 1 from public.profiles p where p.id = u.id
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id, email, full_name, avatar_url, birth_date, phone, line_user_id
  )
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.raw_user_meta_data ->> 'avatar_url',
    nullif(new.raw_user_meta_data ->> 'birth_date', '')::date,
    coalesce(nullif(new.raw_user_meta_data ->> 'phone', ''), '待補電話'),
    new.raw_user_meta_data ->> 'line_user_id'
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = case
      when excluded.full_name <> '' then excluded.full_name
      else profiles.full_name
    end,
    birth_date = coalesce(excluded.birth_date, profiles.birth_date),
    phone = coalesce(excluded.phone, profiles.phone),
    line_user_id = coalesce(excluded.line_user_id, profiles.line_user_id);
  return new;
end;
$$;

alter table public.user_packages
  add column if not exists package_name text;

update public.user_packages
set package_name = coalesce(nullif(package_name, ''), plan_name, '未命名方案')
where package_name is null or package_name = '';

alter table public.user_packages
  alter column package_name set default '未命名方案',
  alter column package_name set not null;

create or replace function public.approve_purchase_order(p_order_id uuid)
returns public.user_packages
language plpgsql
security definer
set search_path = public
as $$
declare
  locked_order public.purchase_orders;
  created_package public.user_packages;
  package_credits integer;
  package_days integer;
  package_type text;
begin
  if not public.is_admin_or_instructor() then
    raise exception 'NOT_AUTHORIZED' using errcode = '42501';
  end if;

  select * into locked_order
  from public.purchase_orders
  where id = p_order_id
  for update;

  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  if locked_order.status <> 'pending_review' then raise exception 'ORDER_ALREADY_REVIEWED'; end if;

  package_credits := case locked_order.plan_id
    when 'trial' then 1
    when 'ten-class' then 10
    when 'monthly' then 999
    else 0
  end;
  package_days := case locked_order.plan_id
    when 'trial' then 30
    when 'ten-class' then 120
    when 'monthly' then 30
    else 365
  end;
  package_type := case locked_order.plan_id
    when 'trial' then 'single'
    when 'ten-class' then 'credits'
    when 'monthly' then 'unlimited'
    else 'stored_value'
  end;

  insert into public.user_packages (
    user_id, owner_id, package_name, total_credits, remaining_credits,
    valid_until, status, plan_name, plan_type, shared_with_phones
  )
  values (
    locked_order.user_id, locked_order.user_id, locked_order.plan_name,
    package_credits, package_credits, current_date + package_days, 'active',
    locked_order.plan_name, package_type, '{}'
  )
  returning * into created_package;

  update public.purchase_orders
  set status = 'approved', package_id = created_package.id, reviewed_at = now()
  where id = locked_order.id;

  return created_package;
end;
$$;

revoke all on function public.approve_purchase_order(uuid) from public;
grant execute on function public.approve_purchase_order(uuid) to authenticated;

notify pgrst, 'reload schema';
