-- Synchronize every Auth account into the member-management profiles table.
-- Safe to run repeatedly; it does not delete existing profiles or packages.
alter table public.profiles
  add column if not exists email text;

alter table public.profiles
  alter column phone set default '';

update public.profiles
set phone = ''
where phone is null;

create or replace function public.sync_auth_profiles()
returns integer
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  synced integer;
begin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and (role = 'admin' or is_instructor = true)
  ) then
    raise exception 'NOT_AUTHORIZED' using errcode = '42501';
  end if;

  insert into public.profiles (id, email, full_name, phone, birth_date, line_user_id, role, is_instructor, is_active)
  select
    u.id,
    u.email,
    coalesce(nullif(u.raw_user_meta_data ->> 'full_name', ''), split_part(coalesce(u.email, ''), '@', 1), '會員'),
    coalesce(nullif(u.raw_user_meta_data ->> 'phone', ''), ''),
    nullif(u.raw_user_meta_data ->> 'birth_date', '')::date,
    nullif(u.raw_user_meta_data ->> 'line_user_id', ''),
    'member',
    false,
    true
  from auth.users u
  on conflict (id) do update
  set email = excluded.email,
      full_name = case when coalesce(public.profiles.full_name, '') = '' then excluded.full_name else public.profiles.full_name end,
      phone = case when coalesce(public.profiles.phone, '') = '' then excluded.phone else public.profiles.phone end;

  get diagnostics synced = row_count;
  return synced;
end;
$$;

revoke all on function public.sync_auth_profiles() from public;
grant execute on function public.sync_auth_profiles() to authenticated;
notify pgrst, 'reload schema';
