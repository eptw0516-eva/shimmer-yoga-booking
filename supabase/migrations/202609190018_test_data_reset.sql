-- Run manually in Supabase SQL Editor only when preparing a fresh integration test.
-- This intentionally does not run automatically.
begin;
delete from public.bookings;
delete from public.purchase_orders;
delete from public.user_packages;
delete from public.classes;
commit;
