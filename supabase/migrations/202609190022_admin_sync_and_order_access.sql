-- Ensure staff can see all member profiles and purchase orders after Auth sync.
alter table public.profiles
  add column if not exists email text;

drop policy if exists "profiles are visible to their owner or staff" on public.profiles;
create policy "profiles are visible to their owner or staff"
  on public.profiles for select
  using (id = auth.uid() or public.is_admin_or_instructor());

drop policy if exists "staff can view all purchase orders" on public.purchase_orders;
create policy "staff can view all purchase orders"
  on public.purchase_orders for select
  using (public.is_admin_or_instructor() or user_id = auth.uid());

notify pgrst, 'reload schema';
