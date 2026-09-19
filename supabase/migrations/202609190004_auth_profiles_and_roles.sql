-- 會員註冊資料與「管理員兼老師」權限模型
alter table public.profiles
  add column if not exists birth_date date,
  add column if not exists is_instructor boolean not null default false,
  add column if not exists is_active boolean not null default true;

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (
    id, full_name, avatar_url, birth_date, phone, line_user_id
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.raw_user_meta_data ->> 'avatar_url',
    nullif(new.raw_user_meta_data ->> 'birth_date', '')::date,
    coalesce(nullif(new.raw_user_meta_data ->> 'phone', ''), '待補電話'),
    new.raw_user_meta_data ->> 'line_user_id'
  )
  on conflict (id) do update set
    full_name = excluded.full_name,
    birth_date = coalesce(excluded.birth_date, profiles.birth_date),
    phone = coalesce(excluded.phone, profiles.phone),
    line_user_id = coalesce(excluded.line_user_id, profiles.line_user_id);
  return new;
end;
$$;

create or replace function public.is_staff()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and is_active and (role = 'admin' or is_instructor)
  );
$$;

create or replace function public.is_admin_or_instructor()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and is_active
      and (role = 'admin' or is_instructor)
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and is_active and role = 'admin'
  );
$$;

create or replace function public.update_member_access(
  p_user_id uuid,
  p_role public.user_role,
  p_is_instructor boolean,
  p_is_active boolean,
  p_full_name text,
  p_phone text,
  p_birth_date date,
  p_line_user_id text
)
returns public.profiles
language plpgsql security definer set search_path = public
as $$
declare updated_profile public.profiles;
begin
  if not public.is_admin() then raise exception 'NOT_AUTHORIZED' using errcode = '42501'; end if;
  update public.profiles set
    role = p_role, is_instructor = p_is_instructor, is_active = p_is_active,
    full_name = p_full_name, phone = p_phone, birth_date = p_birth_date, line_user_id = p_line_user_id
  where id = p_user_id
  returning * into updated_profile;
  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  return updated_profile;
end;
$$;

revoke all on function public.update_member_access(uuid, public.user_role, boolean, boolean, text, text, date, text) from public;
grant execute on function public.update_member_access(uuid, public.user_role, boolean, boolean, text, text, date, text) to authenticated;
