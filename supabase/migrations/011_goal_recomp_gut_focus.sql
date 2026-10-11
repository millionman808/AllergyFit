-- ============================================================
-- Goals are no longer either/or: people can lose fat AND build muscle
-- (recomposition), and "calm my gut" is a goal in its own right that
-- doesn't change calories but changes what the app leads with.
-- ============================================================
alter type fitness_goal add value if not exists 'recomp';

alter table public.profiles
  add column if not exists gut_focus boolean not null default false;
