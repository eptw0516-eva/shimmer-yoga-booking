-- Preserve the purchase-plan details on each issued package.
alter table public.user_packages
  add column if not exists purchase_amount integer,
  add column if not exists unit_price integer,
  add column if not exists plan_description text,
  add column if not exists shareable boolean not null default false;

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
  plan_record public.purchase_plans;
begin
  if not public.is_admin_or_instructor() then
    raise exception 'NOT_AUTHORIZED' using errcode = '42501';
  end if;

  select * into locked_order from public.purchase_orders where id = p_order_id for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  if locked_order.status <> 'pending_review' then raise exception 'ORDER_ALREADY_REVIEWED'; end if;

  select * into plan_record from public.purchase_plans where id = locked_order.plan_id;
  package_credits := coalesce(plan_record.credits, case locked_order.plan_id when 'trial' then 1 when 'ten-class' then 10 when 'monthly' then 999 else 0 end);
  package_days := coalesce(plan_record.valid_days, case locked_order.plan_id when 'trial' then 30 when 'ten-class' then 120 when 'monthly' then 30 else 365 end);
  package_type_value := coalesce(plan_record.category, case locked_order.plan_id when 'trial' then 'single' when 'ten-class' then 'credits' when 'monthly' then 'unlimited' else 'stored_value' end);

  insert into public.user_packages (
    user_id, owner_id, package_name, initial_credits, total_credits, remaining_credits,
    valid_until, status, plan_name, plan_type, shared_with_phones,
    purchase_amount, unit_price, plan_description, shareable
  )
  values (
    locked_order.user_id, locked_order.user_id, locked_order.plan_name, package_credits, package_credits, package_credits,
    current_date + package_days, 'active', locked_order.plan_name, package_type_value, '{}',
    locked_order.amount, plan_record.unit_price, plan_record.description, coalesce(plan_record.shareable, false)
  )
  returning * into created_package;

  update public.purchase_orders set status = 'approved', package_id = created_package.id, reviewed_at = now()
  where id = locked_order.id;
  return created_package;
end;
$$;

revoke all on function public.approve_purchase_order(uuid) from public;
grant execute on function public.approve_purchase_order(uuid) to authenticated;
notify pgrst, 'reload schema';
