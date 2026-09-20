-- Persist class waitlists and promote the first eligible person after a normal cancellation.
create table if not exists public.class_waitlists (
  id uuid primary key default uuid_generate_v4(),
  class_id uuid not null references public.classes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  position integer not null,
  status text not null default 'pending' check (status in ('pending', 'promoted', 'cancelled')),
  created_at timestamptz not null default now()
);

create unique index if not exists class_waitlists_one_pending
  on public.class_waitlists(class_id, user_id) where status = 'pending';
create index if not exists class_waitlists_order_idx
  on public.class_waitlists(class_id, status, position, created_at);

alter table public.class_waitlists enable row level security;
drop policy if exists "Users can view own waitlists" on public.class_waitlists;
create policy "Users can view own waitlists" on public.class_waitlists
  for select using (user_id = auth.uid() or public.is_admin_or_instructor());
drop policy if exists "Users can join waitlists" on public.class_waitlists;
create policy "Users can join waitlists" on public.class_waitlists
  for insert with check (user_id = auth.uid());

create or replace function public.join_class_waitlist(p_class_id uuid)
returns public.class_waitlists
language plpgsql security definer set search_path = public
as $$
declare
  target_class public.classes;
  created_entry public.class_waitlists;
  next_position integer;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHORIZED' using errcode = '42501'; end if;
  select * into target_class from public.classes where id = p_class_id for update;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  if target_class.start_time <= now() then raise exception 'CLASS_STARTED'; end if;
  if target_class.booked_count < target_class.capacity then raise exception 'CLASS_NOT_FULL'; end if;
  if exists (select 1 from public.bookings where class_id = p_class_id and user_id = auth.uid() and status = 'confirmed') then
    raise exception 'ALREADY_BOOKED';
  end if;
  if exists (select 1 from public.class_waitlists where class_id = p_class_id and user_id = auth.uid() and status = 'pending') then
    raise exception 'ALREADY_WAITLISTED';
  end if;
  select coalesce(max(position), 0) + 1 into next_position
  from public.class_waitlists
  where class_id = p_class_id and status = 'pending';
  insert into public.class_waitlists (class_id, user_id, position)
  values (p_class_id, auth.uid(), next_position)
  returning * into created_entry;
  return created_entry;
end;
$$;

create or replace function public.promote_class_waitlist(p_class_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  target_class public.classes;
  candidate public.class_waitlists;
  candidate_package public.user_packages;
  promoted_booking public.bookings;
begin
  select * into target_class from public.classes where id = p_class_id for update;
  if not found then return; end if;
  if target_class.booked_count >= target_class.capacity then return; end if;

  for candidate in
    select * from public.class_waitlists
    where class_id = p_class_id and status = 'pending'
    order by position, created_at
  loop
    exit when target_class.booked_count >= target_class.capacity;
    if exists (select 1 from public.bookings where class_id = p_class_id and user_id = candidate.user_id and status = 'confirmed') then
      update public.class_waitlists set status = 'promoted' where id = candidate.id;
      continue;
    end if;
    select * into candidate_package
    from public.user_packages
    where user_id = candidate.user_id
      and status = 'active'
      and valid_until >= current_date
      and remaining_credits > 0
    order by valid_until, created_at
    limit 1
    for update;
    if not found then continue; end if;

    update public.user_packages
    set remaining_credits = remaining_credits - 1
    where id = candidate_package.id;
    update public.classes
    set booked_count = booked_count + 1
    where id = p_class_id
    returning * into target_class;
    insert into public.bookings (user_id, class_id, status)
    values (candidate.user_id, p_class_id, 'confirmed')
    returning * into promoted_booking;
    update public.class_waitlists set status = 'promoted' where id = candidate.id;
  end loop;
end;
$$;

create or replace function public.cancel_booking(p_booking_id uuid)
returns public.bookings
language plpgsql security definer set search_path = public
as $$
declare
  locked_booking public.bookings;
  selected_package public.user_packages;
  target_class public.classes;
  updated_booking public.bookings;
begin
  select * into locked_booking from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if auth.uid() <> locked_booking.user_id and not public.is_admin_or_instructor() then
    raise exception 'NOT_AUTHORIZED' using errcode = '42501';
  end if;
  if locked_booking.status <> 'confirmed' then raise exception 'BOOKING_NOT_ACTIVE'; end if;
  select * into target_class from public.classes where id = locked_booking.class_id;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  if target_class.start_time - now() < interval '30 minutes' then raise exception 'USE_LATE_CANCEL'; end if;

  select * into selected_package from public.user_packages
  where user_id = locked_booking.user_id and status = 'active'
  order by valid_until desc, created_at desc limit 1 for update;
  if found then
    update public.user_packages
    set remaining_credits = least(total_credits, remaining_credits + 1)
    where id = selected_package.id;
  end if;
  update public.classes set booked_count = greatest(0, booked_count - 1) where id = locked_booking.class_id;
  update public.bookings set status = 'cancelled', updated_at = now()
  where id = locked_booking.id returning * into updated_booking;
  perform public.promote_class_waitlist(locked_booking.class_id);
  return updated_booking;
end;
$$;

revoke all on function public.join_class_waitlist(uuid) from public;
grant execute on function public.join_class_waitlist(uuid) to authenticated;
revoke all on function public.promote_class_waitlist(uuid) from public;
grant execute on function public.promote_class_waitlist(uuid) to authenticated;
revoke all on function public.cancel_booking(uuid) from public;
grant execute on function public.cancel_booking(uuid) to authenticated;
notify pgrst, 'reload schema';
