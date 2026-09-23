-- Keep Auth sign-up from failing when profiles.phone is required.
-- The registration form stores these values in raw_user_meta_data.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_line_user_id text;
  safe_line_user_id text;
begin
  requested_line_user_id := nullif(new.raw_user_meta_data ->> 'line_user_id', '');
  safe_line_user_id := requested_line_user_id;

  if requested_line_user_id is not null
    and exists (
      select 1
      from public.profiles
      where line_user_id = requested_line_user_id
        and id <> new.id
    )
  then
    safe_line_user_id := null;
  end if;
  insert into public.profiles (
    id,
    email,
    full_name,
    avatar_url,
    birth_date,
    phone,
    line_user_id
  )
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.raw_user_meta_data ->> 'avatar_url',
    nullif(new.raw_user_meta_data ->> 'birth_date', '')::date,
    coalesce(nullif(new.raw_user_meta_data ->> 'phone', ''), '待補電話'),
    safe_line_user_id
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = case
      when excluded.full_name <> '' then excluded.full_name
      else public.profiles.full_name
    end,
    birth_date = coalesce(excluded.birth_date, public.profiles.birth_date),
    phone = coalesce(nullif(excluded.phone, ''), public.profiles.phone),
    line_user_id = coalesce(excluded.line_user_id, public.profiles.line_user_id);
  return new;
end;
$$;

notify pgrst, 'reload schema';
