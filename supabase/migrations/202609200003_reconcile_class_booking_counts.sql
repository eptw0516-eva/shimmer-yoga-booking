-- Keep the class counter used by the schedule and admin screens aligned with
-- confirmed bookings that already exist in the database.
update public.classes as c
set booked_count = (
  select count(*)::integer
  from public.bookings as b
  where b.class_id = c.id
    and b.status = 'confirmed'
);

drop policy if exists "staff can view all bookings" on public.bookings;
create policy "staff can view all bookings"
  on public.bookings for select
  using (user_id = auth.uid() or public.is_admin_or_instructor());

notify pgrst, 'reload schema';
