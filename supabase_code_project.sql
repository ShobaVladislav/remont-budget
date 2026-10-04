-- НОВАЯ СХЕМА: доступ по коду проекта вместо регистрации.
-- Важно: этот SQL удалит старые таблицы приложения repair_* и их данные.
-- Если в них уже есть важные расходы, остановитесь и сообщите мне.

drop table if exists public.repair_photos cascade;
drop table if exists public.repair_expenses cascade;
drop table if exists public.repair_settings cascade;

create table public.repair_settings (
  project_key text primary key,
  budget numeric not null default 0,
  rate numeric not null default 3.2,
  updated_at timestamptz not null default now()
);

create table public.repair_expenses (
  id uuid primary key,
  project_key text not null,
  date date not null,
  amount numeric not null,
  currency text not null check (currency in ('BYN','USD')),
  room text not null,
  category text not null,
  description text not null default '',
  created_at timestamptz not null default now()
);

create table public.repair_photos (
  id bigint generated always as identity primary key,
  expense_id uuid not null references public.repair_expenses(id) on delete cascade,
  project_key text not null,
  path text not null,
  url text not null default '',
  created_at timestamptz not null default now()
);

alter table public.repair_settings enable row level security;
alter table public.repair_expenses enable row level security;
alter table public.repair_photos enable row level security;

create policy "project settings access" on public.repair_settings
for all to anon
using (project_key = coalesce(current_setting('request.headers', true)::json->>'x-project-key',''))
with check (project_key = coalesce(current_setting('request.headers', true)::json->>'x-project-key',''));

create policy "project expenses access" on public.repair_expenses
for all to anon
using (project_key = coalesce(current_setting('request.headers', true)::json->>'x-project-key',''))
with check (project_key = coalesce(current_setting('request.headers', true)::json->>'x-project-key',''));

create policy "project photos access" on public.repair_photos
for all to anon
using (project_key = coalesce(current_setting('request.headers', true)::json->>'x-project-key',''))
with check (project_key = coalesce(current_setting('request.headers', true)::json->>'x-project-key',''));

grant select, insert, update, delete on public.repair_settings to anon;
grant select, insert, update, delete on public.repair_expenses to anon;
grant select, insert, update, delete on public.repair_photos to anon;
grant usage, select on sequence public.repair_photos_id_seq to anon;

insert into storage.buckets (id,name,public)
values ('repair-receipts','repair-receipts',false)
on conflict (id) do update set public=false;

drop policy if exists "receipt upload own" on storage.objects;
drop policy if exists "receipt read public" on storage.objects;
drop policy if exists "receipt delete own" on storage.objects;

create policy "project receipt upload" on storage.objects
for insert to anon
with check (
  bucket_id='repair-receipts'
  and (storage.foldername(name))[1] = coalesce(current_setting('request.headers', true)::json->>'x-project-key','')
);

create policy "project receipt read" on storage.objects
for select to anon
using (
  bucket_id='repair-receipts'
  and (storage.foldername(name))[1] = coalesce(current_setting('request.headers', true)::json->>'x-project-key','')
);

create policy "project receipt delete" on storage.objects
for delete to anon
using (
  bucket_id='repair-receipts'
  and (storage.foldername(name))[1] = coalesce(current_setting('request.headers', true)::json->>'x-project-key','')
);
