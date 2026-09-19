-- Restores class visibility and staff write access on legacy deployments.
-- Safe to run repeatedly.

alter table public.classes enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'classes'
      and policyname = 'anyone can view upcoming classes'
  ) then
    create policy "anyone can view upcoming classes"
      on public.classes
      for select
      using (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'classes'
      and policyname = 'staff manage classes'
  ) then
    create policy "staff manage classes"
      on public.classes
      for all
      using (public.is_admin_or_instructor())
      with check (public.is_admin_or_instructor());
  end if;
end $$;

notify pgrst, 'reload schema';
