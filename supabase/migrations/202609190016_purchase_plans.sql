create table if not exists public.purchase_plans (
  id text primary key,
  category text not null check (category in ('single', 'credits', 'stored_value', 'unlimited')),
  name text not null,
  badge text,
  note text,
  description text not null default '',
  valid_days integer not null default 30 check (valid_days > 0),
  shareable boolean not null default false,
  credits integer,
  unit_price integer not null default 0 check (unit_price >= 0),
  total_price integer not null default 0 check (total_price >= 0),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.purchase_plans (id, category, name, badge, note, description, valid_days, shareable, credits, unit_price, total_price, sort_order)
values
  ('trial', 'single', '單堂體驗票', '初次體驗', '初次體驗', '第一次來微光，從一堂舒服的空中瑜珈開始。', 30, false, 1, 650, 650, 1),
  ('ten-class', 'credits', '10 堂計次包', '最受歡迎', '最受歡迎', '彈性安排練習，適合穩定累積身體的力量。', 120, true, 10, 480, 4800, 2),
  ('monthly', 'unlimited', '月費吃到飽', null, null, '一個月內不限堂數，讓練習成為生活日常。', 30, false, 999, 3200, 3200, 3),
  ('stored-value', 'stored_value', '儲值金 3,000', null, null, '儲值後依單堂課價格彈性扣款。', 365, true, null, 3000, 3000, 4)
on conflict (id) do nothing;

alter table public.purchase_plans enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'purchase_plans' and policyname = 'anyone can view active purchase plans') then
    create policy "anyone can view active purchase plans" on public.purchase_plans for select using (is_active = true or public.is_admin());
  end if;
  if not exists (select 1 from pg_policies where tablename = 'purchase_plans' and policyname = 'admins manage purchase plans') then
    create policy "admins manage purchase plans" on public.purchase_plans for all using (public.is_admin()) with check (public.is_admin());
  end if;
end $$;

notify pgrst, 'reload schema';
