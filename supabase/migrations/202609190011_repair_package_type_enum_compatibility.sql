-- Compatibility repair for deployments with a different package_type enum.
-- This migration discovers the enum labels instead of assuming names such as
-- "credits" or "single".

do $$
declare
  enum_schema text;
  enum_name text;
  fallback_label text;
  preferred_label text;
begin
  select n.nspname, t.typname
  into enum_schema, enum_name
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_type t on t.oid = a.atttypid
  join pg_namespace n on n.oid = t.typnamespace
  where c.relname = 'user_packages'
    and a.attname = 'package_type'
    and t.typtype = 'e'
  limit 1;

  if enum_name is not null then
    select e.enumlabel
    into fallback_label
    from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = enum_schema
      and t.typname = enum_name
    order by e.enumsortorder
    limit 1;

    select e.enumlabel
    into preferred_label
    from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = enum_schema
      and t.typname = enum_name
      and lower(e.enumlabel) in ('single', 'single_class', 'trial', 'class', 'package')
    order by e.enumsortorder
    limit 1;

    fallback_label := coalesce(preferred_label, fallback_label);

    execute format(
      'update public.user_packages set package_type = %L::%I.%I where package_type is null',
      fallback_label, enum_schema, enum_name
    );
    execute format(
      'alter table public.user_packages alter column package_type set default %L::%I.%I',
      fallback_label, enum_schema, enum_name
    );
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

  -- package_type is intentionally omitted: the compatibility default above
  -- supplies a valid label for the deployed enum.
  insert into public.user_packages (
    user_id, owner_id, package_name,
    total_credits, remaining_credits, valid_until, status,
    plan_name, plan_type, shared_with_phones
  )
  values (
    locked_order.user_id, locked_order.user_id, locked_order.plan_name,
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
