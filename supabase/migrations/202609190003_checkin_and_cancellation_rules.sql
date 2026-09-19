-- 現場 QR 簽到與課前三小時取消規則
alter type public.booking_status add value if not exists 'late_cancelled';
alter table public.bookings add column if not exists checked_in_at timestamptz;

create or replace function public.checkin_class(p_booking_id uuid, p_token text)
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

  select * into locked_booking from public.bookings
    where id = p_booking_id and user_id = auth.uid() for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if locked_booking.status <> 'confirmed' then raise exception 'BOOKING_NOT_ACTIVE'; end if;
  select * into target_class from public.classes where id = locked_booking.class_id;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  if now() < target_class.start_time - interval '30 minutes'
     or now() > target_class.end_time + interval '15 minutes' then
    raise exception 'CHECKIN_WINDOW_CLOSED';
  end if;

  update public.bookings
    set status = 'attended', checked_in_at = now(), updated_at = now()
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
  select * into locked_booking from public.bookings
    where id = p_booking_id and (user_id = auth.uid() or public.is_admin_or_instructor()) for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if locked_booking.status <> 'confirmed' then raise exception 'BOOKING_NOT_ACTIVE'; end if;
  select * into target_class from public.classes where id = locked_booking.class_id;
  if target_class.start_time - now() >= interval '3 hours' then raise exception 'USE_FREE_CANCEL'; end if;

  update public.classes set booked_count = greatest(0, booked_count - 1) where id = locked_booking.class_id;
  update public.bookings set status = 'late_cancelled', updated_at = now()
    where id = locked_booking.id returning * into updated_booking;
  return updated_booking;
end;
$$;

revoke all on function public.checkin_class(uuid, text) from public;
grant execute on function public.checkin_class(uuid, text) to authenticated;
revoke all on function public.late_cancel_booking(uuid) from public;
grant execute on function public.late_cancel_booking(uuid) to authenticated;
