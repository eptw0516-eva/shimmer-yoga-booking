-- Repair legacy user_packages tables that were created before user ownership
-- and purchase-plan metadata were added.

alter table public.user_packages
  add column if not exists user_id uuid,
  add column if not exists total_credits integer not null default 0,
  add column if not exists remaining_credits integer not null default 0,
  add column if not exists valid_until date not null default current_date,
  add column if not exists status public.package_status not null default 'active',
  add column if not exists note text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.user_packages'::regclass
      and conname = 'user_packages_user_id_fkey'
  ) then
    alter table public.user_packages
      add constraint user_packages_user_id_fkey
      foreign key (user_id) references public.profiles(id) on delete cascade;
  end if;
end $$;

alter table public.user_packages
  add column if not exists plan_name text,
  add column if not exists plan_type text,
  add column if not exists shared_with_phones text[] not null default '{}';

alter table public.user_packages enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_packages'
      and policyname = 'members read their packages'
  ) then
    create policy "members read their packages" on public.user_packages
      for select using (user_id = auth.uid() or public.is_admin_or_instructor());
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_packages'
      and policyname = 'staff manage packages'
  ) then
    create policy "staff manage packages" on public.user_packages
      for all using (public.is_admin_or_instructor())
      with check (public.is_admin_or_instructor());
  end if;
end $$;

notify pgrst, 'reload schema';
