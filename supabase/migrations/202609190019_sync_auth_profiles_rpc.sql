create or replace function public.sync_auth_profiles()
returns integer
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  synced integer;
begin
  if not public.is_admin_or_instructor() then
    raise exception 'NOT_AUTHORIZED' using errcode = '42501';
  end if;

  insert into public.profiles (id, email, full_name, phone, birth_date, line_user_id, role, is_instructor, is_active)
  select
    users.id,
    users.email,
    coalesce(users.raw_user_meta_data ->> 'full_name', split_part(coalesce(users.email, ''), '@', 1), '會員'),
    users.raw_user_meta_data ->> 'phone',
    nullif(users.raw_user_meta_data ->> 'birth_date', '')::date,
    users.raw_user_meta_data ->> 'line_user_id',
    'member',
    false,
    true
  from auth.users users
  on conflict (id) do update set
    email = excluded.email,
    full_name = case when public.profiles.full_name is null or public.profiles.full_name = '' then excluded.full_name else public.profiles.full_name end,
    phone = coalesce(public.profiles.phone, excluded.phone);

  get diagnostics synced = row_count;
  return synced;
end;
$$;

revoke all on function public.sync_auth_profiles() from public;
grant execute on function public.sync_auth_profiles() to authenticated;
