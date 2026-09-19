-- Repairs legacy deployments that require package_type and classes.room.
-- Safe to run repeatedly.

alter table public.user_packages
  add column if not exists package_type text;

update public.user_packages
set package_type = coalesce(plan_type, 'credits')::public.package_type
where package_type is null;

alter table public.user_packages
  alter column package_type set default 'credits',
  alter column package_type set not null;

alter table public.classes
  add column if not exists room text;

update public.classes
set room = 'A 教室'
where room is null or room = '';

alter table public.classes
  alter column room set default 'A 教室',
  alter column room set not null;

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
  package_type_value text;
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
  package_type_value := case locked_order.plan_id
    when 'trial' then 'single'
    when 'ten-class' then 'credits'
    when 'monthly' then 'unlimited'
    else 'stored_value'
  end;

  insert into public.user_packages (
    user_id, owner_id, package_name, package_type,
    total_credits, remaining_credits, valid_until, status,
    plan_name, plan_type, shared_with_phones
  )
  values (
    locked_order.user_id, locked_order.user_id, locked_order.plan_name, package_type_value::public.package_type,
    package_credits, package_credits, current_date + package_days, 'active',
    locked_order.plan_name, package_type_value, '{}'
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
