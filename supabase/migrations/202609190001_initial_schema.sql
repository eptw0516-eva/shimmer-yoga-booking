-- 拾光瑜伽初始資料結構
-- PostgreSQL functions are atomic by default; do not put BEGIN/COMMIT inside them.

create extension if not exists "uuid-ossp";

create type public.user_role as enum ('member', 'instructor', 'admin');
create type public.package_status as enum ('active', 'expired', 'depleted');
create type public.booking_status as enum ('confirmed', 'cancelled', 'attended', 'no_show');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.user_role not null default 'member',
  line_user_id text unique,
  phone text,
  full_name text not null default '',
  avatar_url text,
  created_at timestamptz not null default now()
);

create table public.user_packages (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  total_credits integer not null check (total_credits >= 0),
  remaining_credits integer not null check (remaining_credits >= 0 and remaining_credits <= total_credits),
  valid_until date not null,
  status public.package_status not null default 'active',
  note text,
  created_at timestamptz not null default now()
);

create table public.classes (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  description text,
  instructor_id uuid not null references public.profiles(id),
  room text not null default 'A 教室',
  start_time timestamptz not null,
  end_time timestamptz not null check (end_time > start_time),
  capacity integer not null check (capacity > 0),
  booked_count integer not null default 0 check (booked_count >= 0),
  level text not null default '初階' check (level in ('初階', '中階', '進階')),
  created_at timestamptz not null default now()
);

create table public.bookings (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  status public.booking_status not null default 'confirmed',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index bookings_one_active_per_user_class
  on public.bookings(user_id, class_id) where status = 'confirmed';
create index classes_start_time_idx on public.classes(start_time);
create index bookings_user_id_idx on public.bookings(user_id);

create or replace function public.is_admin_or_instructor()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin', 'instructor')
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), new.raw_user_meta_data ->> 'avatar_url')
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.book_class(p_class_id uuid, p_user_id uuid)
returns public.bookings
language plpgsql security definer set search_path = public
as $$
declare
  locked_class public.classes;
  selected_package public.user_packages;
  created_booking public.bookings;
begin
  if auth.uid() is null or (auth.uid() <> p_user_id and not public.is_admin_or_instructor()) then
    raise exception 'NOT_AUTHORIZED' using errcode = '42501';
  end if;

  select * into locked_class from public.classes where id = p_class_id for update;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  if locked_class.booked_count >= locked_class.capacity then raise exception 'CLASS_FULL'; end if;
  if locked_class.start_time <= now() then raise exception 'CLASS_STARTED'; end if;
  if exists (select 1 from public.bookings where user_id = p_user_id and class_id = p_class_id and status = 'confirmed') then
    raise exception 'ALREADY_BOOKED';
  end if;

  select * into selected_package
  from public.user_packages
  where user_id = p_user_id and status = 'active'
    and valid_until >= current_date and remaining_credits > 0
  order by valid_until, created_at
  limit 1 for update;
  if not found then raise exception 'INSUFFICIENT_CREDITS'; end if;

  update public.user_packages
    set remaining_credits = remaining_credits - 1,
        status = case when remaining_credits - 1 = 0 then 'depleted' else status end
    where id = selected_package.id;
  update public.classes set booked_count = booked_count + 1 where id = locked_class.id;
  insert into public.bookings (user_id, class_id, status)
    values (p_user_id, p_class_id, 'confirmed')
    returning * into created_booking;
  return created_booking;
end;
$$;

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
    update public.user_packages set remaining_credits = least(total_credits, remaining_credits + 1), status = 'active'
      where id = selected_package.id;
  end if;
  update public.classes set booked_count = greatest(0, booked_count - 1) where id = locked_booking.class_id;
  update public.bookings set status = 'cancelled', updated_at = now() where id = locked_booking.id returning * into updated_booking;
  return updated_booking;
end;
$$;

alter table public.profiles enable row level security;
alter table public.user_packages enable row level security;
alter table public.classes enable row level security;
alter table public.bookings enable row level security;

create policy "profiles are visible to their owner or staff" on public.profiles
  for select using (id = auth.uid() or public.is_admin_or_instructor());
create policy "users update their own profile" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());
create policy "staff manage profiles" on public.profiles
  for all using (public.is_admin_or_instructor()) with check (public.is_admin_or_instructor());

create policy "members read their packages" on public.user_packages
  for select using (user_id = auth.uid() or public.is_admin_or_instructor());
create policy "staff manage packages" on public.user_packages
  for all using (public.is_admin_or_instructor()) with check (public.is_admin_or_instructor());

create policy "anyone can view upcoming classes" on public.classes
  for select using (true);
create policy "staff manage classes" on public.classes
  for all using (public.is_admin_or_instructor()) with check (public.is_admin_or_instructor());

create policy "members view their bookings" on public.bookings
  for select using (user_id = auth.uid() or public.is_admin_or_instructor());
create policy "instructors can update attendance" on public.bookings
  for update using (public.is_admin_or_instructor()) with check (public.is_admin_or_instructor());

revoke all on function public.book_class(uuid, uuid) from public;
grant execute on function public.book_class(uuid, uuid) to authenticated;
revoke all on function public.cancel_booking(uuid) from public;
grant execute on function public.cancel_booking(uuid) to authenticated;
