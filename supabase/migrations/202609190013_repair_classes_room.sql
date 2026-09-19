-- Standalone repair for legacy classes tables.
-- Kept separate so course creation is not blocked by package migrations.

alter table public.classes
  add column if not exists room text;

update public.classes
set room = 'A 教室'
where room is null or room = '';

alter table public.classes
  alter column room set default 'A 教室',
  alter column room set not null;

notify pgrst, 'reload schema';
