-- Saved recipes (browse + save from recipe search)
create table if not exists public.saved_recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  url text not null,
  image_url text,
  ingredients jsonb default '[]',
  calories int,
  created_at timestamptz not null default now(),
  unique (user_id, url)
);

alter table public.saved_recipes enable row level security;
create policy "own rows select" on public.saved_recipes for select to authenticated using (user_id = auth.uid());
create policy "own rows insert" on public.saved_recipes for insert to authenticated with check (user_id = auth.uid());
create policy "own rows delete" on public.saved_recipes for delete to authenticated using (user_id = auth.uid());
