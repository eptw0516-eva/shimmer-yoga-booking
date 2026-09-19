-- Repair actions for projects where an earlier migration stopped part-way through.
-- Run this once in Supabase SQL Editor after migrations 001-004.

create or replace function public.cancel_booking(p_booking_id uuid)
returns public.bookings
language plpgsql security definer set search_path = public
as $$
declare
  locked_booking public.bookings;
  selected_package public.user_packages;
  updated_booking public.bookings;
begin
  select * into locked_booking from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if auth.uid() <> locked_booking.user_id and not public.is_admin_or_instructor() then
    raise exception 'NOT_AUTHORIZED' using errcode = '42501';
  end if;
  if locked_booking.status <> 'confirmed' then raise exception 'BOOKING_NOT_ACTIVE'; end if;
  select * into selected_package from public.user_packages
    where user_id = locked_booking.user_id and status in ('active', 'depleted')
    order by valid_until desc, created_at desc limit 1 for update;
  if found then
    update public.user_packages
      set remaining_credits = least(total_credits, remaining_credits + 1), status = 'active'
      where id = selected_package.id;
  end if;
  update public.classes set booked_count = greatest(0, booked_count - 1) where id = locked_booking.class_id;
  update public.bookings set status = 'cancelled', updated_at = now()
    where id = locked_booking.id returning * into updated_booking;
  return updated_booking;
end;
$$;

revoke all on function public.cancel_booking(uuid) from public;
grant execute on function public.cancel_booking(uuid) to authenticated;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'purchase_order_status') then
    create type public.purchase_order_status as enum ('pending_review', 'approved', 'rejected');
  end if;
  if not exists (select 1 from pg_type where typname = 'payment_method') then
    create type public.payment_method as enum ('bank_transfer', 'cash');
  end if;
end $$;

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
begin
  if not public.is_admin_or_instructor() then raise exception 'NOT_AUTHORIZED' using errcode = '42501'; end if;
  select * into locked_order from public.purchase_orders where id = p_order_id for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  if locked_order.status <> 'pending_review' then raise exception 'ORDER_ALREADY_REVIEWED'; end if;
  package_credits := case locked_order.plan_id when 'trial' then 1 when 'ten-class' then 10 when 'monthly' then 999 else 0 end;
  package_days := case locked_order.plan_id when 'trial' then 30 when 'ten-class' then 120 when 'monthly' then 30 else 365 end;
  package_type := case locked_order.plan_id when 'trial' then 'single' when 'ten-class' then 'credits' when 'monthly' then 'unlimited' else 'stored_value' end;
  insert into public.user_packages (user_id, total_credits, remaining_credits, valid_until, status, plan_name, plan_type, shared_with_phones)
    values (locked_order.user_id, package_credits, package_credits, current_date + package_days, 'active', locked_order.plan_name, package_type, '{}')
    returning * into created_package;
  update public.purchase_orders set status = 'approved', package_id = created_package.id, reviewed_at = now() where id = locked_order.id;
  return created_package;
end;
$$;

revoke all on function public.approve_purchase_order(uuid) from public;
grant execute on function public.approve_purchase_order(uuid) to authenticated;

alter table public.user_packages
  add column if not exists plan_name text,
  add column if not exists plan_type text,
  add column if not exists shared_with_phones text[] not null default '{}';

create table if not exists public.purchase_orders (
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
do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'purchase_orders' and policyname = 'members view their purchase orders') then
    create policy "members view their purchase orders" on public.purchase_orders for select using (user_id = auth.uid() or public.is_admin_or_instructor());
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'purchase_orders' and policyname = 'members create their purchase orders') then
    create policy "members create their purchase orders" on public.purchase_orders for insert with check (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'purchase_orders' and policyname = 'staff manage purchase orders') then
    create policy "staff manage purchase orders" on public.purchase_orders for all using (public.is_admin_or_instructor()) with check (public.is_admin_or_instructor());
  end if;
end $$;
