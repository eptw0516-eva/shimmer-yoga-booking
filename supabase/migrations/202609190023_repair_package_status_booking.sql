-- Some legacy databases define package_status without the 'depleted' label.
-- Keep a package active when its balance reaches zero; the balance predicate
-- already prevents it from being selected for another booking.
create or replace function public.book_class(p_class_id uuid, p_user_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
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
  set remaining_credits = remaining_credits - 1
  where id = selected_package.id;
  update public.classes set booked_count = booked_count + 1 where id = locked_class.id;
  insert into public.bookings (user_id, class_id, status)
  values (p_user_id, p_class_id, 'confirmed')
  returning * into created_booking;
  return created_booking;
end;
$$;

revoke all on function public.book_class(uuid, uuid) from public;
grant execute on function public.book_class(uuid, uuid) to authenticated;
notify pgrst, 'reload schema';
