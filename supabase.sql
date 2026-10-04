-- Выполните этот SQL в Supabase SQL Editor.
create table if not exists public.repair_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  budget numeric not null default 0,
  rate numeric not null default 3.2,
  updated_at timestamptz not null default now()
);

create table if not exists public.repair_expenses (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  amount numeric not null,
  currency text not null check (currency in ('BYN','USD')),
  room text not null,
  category text not null,
  description text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.repair_photos (
  id bigint generated always as identity primary key,
  expense_id uuid not null references public.repair_expenses(id) on delete cascade,
  path text not null,
  url text not null,
  created_at timestamptz not null default now()
);

alter table public.repair_settings enable row level security;
alter table public.repair_expenses enable row level security;
alter table public.repair_photos enable row level security;

create policy "settings own" on public.repair_settings for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "expenses own" on public.repair_expenses for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "photos own via expense" on public.repair_photos for select using (
 exists(select 1 from public.repair_expenses e where e.id=expense_id and e.user_id=auth.uid())
);
create policy "photos insert own" on public.repair_photos for insert with check (
 exists(select 1 from public.repair_expenses e where e.id=expense_id and e.user_id=auth.uid())
);
create policy "photos delete own" on public.repair_photos for delete using (
 exists(select 1 from public.repair_expenses e where e.id=expense_id and e.user_id=auth.uid())
);

insert into storage.buckets (id,name,public) values ('repair-receipts','repair-receipts',true)
on conflict (id) do nothing;

create policy "receipt upload own" on storage.objects for insert to authenticated
with check (bucket_id='repair-receipts' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "receipt read public" on storage.objects for select using (bucket_id='repair-receipts');
create policy "receipt delete own" on storage.objects for delete to authenticated
using (bucket_id='repair-receipts' and (storage.foldername(name))[1]=auth.uid()::text);

-- Явно выдаём приложению доступ через Supabase Data API.
grant select, insert, update, delete on public.repair_settings to authenticated;
grant select, insert, update, delete on public.repair_expenses to authenticated;
grant select, insert, update, delete on public.repair_photos to authenticated;
grant usage, select on sequence public.repair_photos_id_seq to authenticated;
