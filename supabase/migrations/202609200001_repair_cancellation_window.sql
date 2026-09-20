-- Cancellation is refundable until 30 minutes before class start.
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
  select * into locked_booking
  from public.bookings
  where id = p_booking_id
  for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if auth.uid() <> locked_booking.user_id and not public.is_admin_or_instructor() then
    raise exception 'NOT_AUTHORIZED' using errcode = '42501';
  end if;
  if locked_booking.status <> 'confirmed' then raise exception 'BOOKING_NOT_ACTIVE'; end if;

  select * into target_class from public.classes where id = locked_booking.class_id;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  if target_class.start_time - now() < interval '30 minutes' then
    raise exception 'USE_LATE_CANCEL';
  end if;

  select * into selected_package
  from public.user_packages
  where user_id = locked_booking.user_id
    and status = 'active'
  order by valid_until desc, created_at desc
  limit 1
  for update;
  if found then
    update public.user_packages
    set remaining_credits = least(total_credits, remaining_credits + 1)
    where id = selected_package.id;
  end if;

  update public.classes
  set booked_count = greatest(0, booked_count - 1)
  where id = locked_booking.class_id;
  update public.bookings
  set status = 'cancelled', updated_at = now()
  where id = locked_booking.id
  returning * into updated_booking;
  return updated_booking;
end;
$$;

create or replace function public.late_cancel_booking(p_booking_id uuid)
returns public.bookings
language plpgsql security definer set search_path = public
as $$
declare
  locked_booking public.bookings;
  target_class public.classes;
  updated_booking public.bookings;
begin
  select * into locked_booking
  from public.bookings
  where id = p_booking_id
    and (user_id = auth.uid() or public.is_admin_or_instructor())
  for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if locked_booking.status <> 'confirmed' then raise exception 'BOOKING_NOT_ACTIVE'; end if;

  select * into target_class from public.classes where id = locked_booking.class_id;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  if target_class.start_time - now() >= interval '30 minutes' then
    raise exception 'USE_FREE_CANCEL';
  end if;

  update public.classes
  set booked_count = greatest(0, booked_count - 1)
  where id = locked_booking.class_id;
  update public.bookings
  set status = 'late_cancelled', updated_at = now()
  where id = locked_booking.id
  returning * into updated_booking;
  return updated_booking;
end;
$$;

revoke all on function public.cancel_booking(uuid) from public;
grant execute on function public.cancel_booking(uuid) to authenticated;
revoke all on function public.late_cancel_booking(uuid) from public;
grant execute on function public.late_cancel_booking(uuid) to authenticated;
notify pgrst, 'reload schema';
