-- Cache Spoonacular search results so repeated searches cost zero API points
-- and return instantly. Only the recipes edge function touches this table
-- (via the service role), so RLS is enabled with no user policies.
create table public.recipe_search_cache (
  key text primary key,               -- normalized "query|allergen,allergen"
  query text not null,
  allergens text[] not null default '{}',
  results jsonb not null,
  created_at timestamptz not null default now()
);
create index recipe_search_cache_created on public.recipe_search_cache(created_at);

alter table public.recipe_search_cache enable row level security;
