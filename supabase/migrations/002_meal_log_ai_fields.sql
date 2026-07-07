-- AI meal logger fields: full nutrition + allergen detection + parse confidence
alter table public.meal_logs
  add column if not exists sugar_g numeric(6,1) check (sugar_g >= 0),
  add column if not exists sodium_mg numeric(7,1) check (sodium_mg >= 0),
  add column if not exists detected_allergens text[] default '{}',
  add column if not exists confidence numeric(3,2) check (confidence between 0 and 1);
