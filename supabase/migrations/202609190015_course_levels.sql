-- Align course levels with the admin form while retaining legacy 進階 rows.
do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select conname
    from pg_constraint
    where conrelid = 'public.classes'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%level%'
  loop
    execute format('alter table public.classes drop constraint %I', constraint_name);
  end loop;
end $$;

alter table public.classes
  add constraint classes_level_check
  check (level in ('初階', '中階', '高階', '進階'));

notify pgrst, 'reload schema';
