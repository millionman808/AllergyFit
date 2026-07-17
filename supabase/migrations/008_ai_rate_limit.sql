-- ============================================================
-- AI usage metering + kill switch (cost-abuse protection)
-- Every Claude-backed edge function checks this before spending money.
-- Counts and config are written ONLY by the backend (service role); the
-- app can never raise its own limits or flip the switch — the exact
-- separation the "user edits their own row" vulnerability is about.
-- ============================================================

-- Per-user daily AI request counter.
create table if not exists public.ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null default current_date,
  count int not null default 0,
  primary key (user_id, day)
);
alter table public.ai_usage enable row level security;
-- Users may READ their own usage (e.g. to show "12 of 50 today"); nobody but
-- the service role may write it. No insert/update/delete policy = no user writes.
create policy "own usage select" on public.ai_usage
  for select to authenticated using (user_id = auth.uid());

-- Global config: kill switch + daily limit, tweakable without a redeploy.
create table if not exists public.service_config (
  id int primary key default 1,
  ai_enabled boolean not null default true,
  daily_ai_limit int not null default 50,
  constraint service_config_singleton check (id = 1)
);
alter table public.service_config enable row level security;
-- No policies at all → only the service role (bypasses RLS) can read/write.
insert into public.service_config (id) values (1) on conflict (id) do nothing;

-- Atomic per-user daily increment; returns the new count. security definer so
-- the counter is consistent regardless of caller, but execute is locked down
-- to the service role only.
create or replace function public.bump_ai_usage(p_user uuid, p_day date)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  new_count int;
begin
  insert into public.ai_usage (user_id, day, count)
  values (p_user, p_day, 1)
  on conflict (user_id, day)
  do update set count = public.ai_usage.count + 1
  returning count into new_count;
  return new_count;
end;
$$;

revoke all on function public.bump_ai_usage(uuid, date) from public, anon, authenticated;
