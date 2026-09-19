-- Repairs older deployments that used user_packages.owner_id and omitted
-- classes.level. Safe to run repeatedly.

alter table public.user_packages
  add column if not exists owner_id uuid;

alter table public.classes
  add column if not exists level text not null default '初階';

update public.user_packages
set user_id = owner_id
where user_id is null
  and owner_id is not null;

update public.user_packages
set owner_id = user_id
where owner_id is null
  and user_id is not null;

alter table public.user_packages
  alter column owner_id drop not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.user_packages'::regclass
      and conname = 'user_packages_owner_id_fkey'
  ) then
    alter table public.user_packages
      add constraint user_packages_owner_id_fkey
      foreign key (owner_id) references public.profiles(id) on delete cascade;
  end if;
end $$;

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

  select *
  into locked_order
  from public.purchase_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'ORDER_NOT_FOUND';
  end if;
  if locked_order.status <> 'pending_review' then
    raise exception 'ORDER_ALREADY_REVIEWED';
  end if;

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
    user_id,
    owner_id,
    total_credits,
    remaining_credits,
    valid_until,
    status,
    plan_name,
    plan_type,
    shared_with_phones
  )
  values (
    locked_order.user_id,
    locked_order.user_id,
    package_credits,
    package_credits,
    current_date + package_days,
    'active',
    locked_order.plan_name,
    package_type,
    '{}'
  )
  returning * into created_package;

  update public.purchase_orders
  set status = 'approved',
      package_id = created_package.id,
      reviewed_at = now()
  where id = locked_order.id;

  return created_package;
end;
$$;

revoke all on function public.approve_purchase_order(uuid) from public;
grant execute on function public.approve_purchase_order(uuid) to authenticated;

notify pgrst, 'reload schema';
