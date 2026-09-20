-- Validate that a course-specific QR Code is used for the matching booking.
create or replace function public.checkin_class_for_course(
  p_booking_id uuid,
  p_class_id uuid,
  p_token text
)
returns public.bookings
language plpgsql security definer set search_path = public
as $$
declare
  locked_booking public.bookings;
  target_class public.classes;
  updated_booking public.bookings;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHORIZED' using errcode = '42501'; end if;
  if p_token <> 'SHIMMER_CHECKIN_SECRET' then raise exception 'INVALID_CHECKIN_QR'; end if;

  select * into locked_booking
  from public.bookings
  where id = p_booking_id
    and user_id = auth.uid()
    and class_id = p_class_id
  for update;
  if not found then raise exception 'BOOKING_NOT_FOUND_FOR_CLASS'; end if;
  if locked_booking.status <> 'confirmed' then raise exception 'BOOKING_NOT_ACTIVE'; end if;

  select * into target_class from public.classes where id = p_class_id;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  if now() < target_class.start_time - interval '30 minutes'
     or now() > target_class.end_time + interval '15 minutes' then
    raise exception 'CHECKIN_WINDOW_CLOSED'; end if;

  update public.bookings
  set status = 'attended', checked_in_at = now(), updated_at = now()
  where id = locked_booking.id
  returning * into updated_booking;
  return updated_booking;
end;
$$;

revoke all on function public.checkin_class_for_course(uuid, uuid, text) from public;
grant execute on function public.checkin_class_for_course(uuid, uuid, text) to authenticated;
notify pgrst, 'reload schema';
