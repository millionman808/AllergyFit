-- Store cooking directions + full macros with saved recipes so they show up
-- in the Saved tab across devices (previously only title/ingredients/calories).
alter table public.saved_recipes
  add column if not exists directions jsonb not null default '[]'::jsonb,
  add column if not exists protein int,
  add column if not exists carbs int,
  add column if not exists fat int;
