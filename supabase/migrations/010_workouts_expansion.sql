-- ============================================================
-- Workouts table expansion: calories burned, distance, heart rate, source, external id
-- ============================================================

alter table public.workouts
  add column if not exists calories_burned int check (calories_burned >= 0),
  add column if not exists distance_meters numeric(8,2) check (distance_meters >= 0),
  add column if not exists avg_heart_rate int check (avg_heart_rate between 30 and 260),
  add column if not exists source text default 'manual',
  add column if not exists external_id text,
  add column if not exists sets_data jsonb default '[]';

create index if not exists workouts_external_id on public.workouts(user_id, external_id) where external_id is not null;
