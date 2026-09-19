-- 購課申請、人工核款與共享堂數包
create type public.purchase_order_status as enum ('pending_review', 'approved', 'rejected');
create type public.payment_method as enum ('bank_transfer', 'cash');

alter table public.user_packages
  add column if not exists plan_name text,
  add column if not exists plan_type text,
  add column if not exists shared_with_phones text[] not null default '{}';

create table public.purchase_orders (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  plan_id text not null,
  plan_name text not null,
  amount integer not null check (amount >= 0),
  payment_method public.payment_method not null,
  transfer_last_five text check (transfer_last_five is null or transfer_last_five ~ '^[0-9]{5}$'),
  status public.purchase_order_status not null default 'pending_review',
  package_id uuid references public.user_packages(id),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

alter table public.purchase_orders enable row level security;
create policy "members view their purchase orders" on public.purchase_orders
  for select using (user_id = auth.uid() or public.is_admin_or_instructor());
create policy "members create their purchase orders" on public.purchase_orders
  for insert with check (user_id = auth.uid());
create policy "staff manage purchase orders" on public.purchase_orders
  for all using (public.is_admin_or_instructor()) with check (public.is_admin_or_instructor());

create or replace function public.approve_purchase_order(p_order_id uuid)
returns public.user_packages
language plpgsql security definer set search_path = public
as $$
declare
  locked_order public.purchase_orders;
  created_package public.user_packages;
  package_credits integer;
  package_days integer;
  package_type text;
  package_shareable boolean;
begin
  if not public.is_admin_or_instructor() then
    raise exception 'NOT_AUTHORIZED' using errcode = '42501';
  end if;

  select * into locked_order from public.purchase_orders where id = p_order_id for update;
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
  package_shareable := locked_order.plan_id in ('ten-class', 'stored-value');

  insert into public.user_packages (
    user_id, total_credits, remaining_credits, valid_until, status,
    plan_name, plan_type, shared_with_phones
  )
  values (
    locked_order.user_id, package_credits, package_credits,
    current_date + package_days, 'active',
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
