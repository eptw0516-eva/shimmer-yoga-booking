-- Synchronize every Auth user without aborting when legacy accounts share a LINE ID.
-- The first existing profile keeps a duplicated LINE ID; conflicting Auth users
-- remain synchronized with a NULL LINE ID and can be edited by an administrator.
create or replace function public.sync_auth_profiles()
returns integer
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  auth_user record;
  synced integer := 0;
  safe_line_user_id text;
begin
  if not public.is_admin_or_instructor() then
    raise exception 'NOT_AUTHORIZED' using errcode = '42501';
  end if;

  for auth_user in
    select *
    from auth.users
    order by created_at, id
  loop
    safe_line_user_id := nullif(auth_user.raw_user_meta_data ->> 'line_user_id', '');

    if safe_line_user_id is not null
      and exists (
        select 1
        from public.profiles
        where line_user_id = safe_line_user_id
          and id <> auth_user.id
      )
    then
      safe_line_user_id := null;
    end if;

    insert into public.profiles (
      id, email, full_name, phone, birth_date, line_user_id,
      role, is_instructor, is_active
    )
    values (
      auth_user.id,
      auth_user.email,
      coalesce(nullif(auth_user.raw_user_meta_data ->> 'full_name', ''), split_part(coalesce(auth_user.email, ''), '@', 1), '會員'),
      coalesce(nullif(auth_user.raw_user_meta_data ->> 'phone', ''), ''),
      nullif(auth_user.raw_user_meta_data ->> 'birth_date', '')::date,
      safe_line_user_id,
      'member',
      false,
      true
    )
    on conflict (id) do update set
      email = excluded.email,
      full_name = case
        when public.profiles.full_name is null or public.profiles.full_name = '' then excluded.full_name
        else public.profiles.full_name
      end,
      phone = case
        when public.profiles.phone is null or public.profiles.phone = '' then excluded.phone
        else public.profiles.phone
      end;

    synced := synced + 1;
  end loop;

  return synced;
end;
$$;

revoke all on function public.sync_auth_profiles() from public;
grant execute on function public.sync_auth_profiles() to authenticated;

notify pgrst, 'reload schema';
