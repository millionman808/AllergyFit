-- ============================================================
-- AllergyFit — Phase 1 (MVP) schema
-- Core loop: log meals → log workouts → symptom check-ins
--            → correlation engine → meal plan auto-adjusts
-- ============================================================

-- ---------- Enums ----------
create type fitness_goal as enum ('cut', 'build', 'maintain');
create type activity_level as enum ('sedentary', 'light', 'moderate', 'active', 'very_active');
create type meal_type as enum ('breakfast', 'lunch', 'dinner', 'snack', 'pre_workout', 'post_workout');
create type workout_type as enum ('lifting', 'running', 'cycling', 'crossfit', 'swimming', 'team_sport', 'hiit', 'yoga', 'walking', 'other');
create type workout_intensity as enum ('light', 'moderate', 'hard', 'max');
create type symptom_type as enum ('hives', 'itching', 'gi_distress', 'nausea', 'bloating', 'fatigue', 'headache', 'congestion', 'swelling', 'breathing', 'anaphylaxis', 'skin_flush', 'dizziness', 'other');
create type severity_level as enum ('mild', 'moderate', 'severe');
create type plan_status as enum ('draft', 'active', 'completed', 'archived');

-- ---------- Profiles (1:1 with auth.users) ----------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  fitness_goal fitness_goal default 'maintain',
  birth_year int check (birth_year between 1900 and 2030),
  sex text check (sex in ('male', 'female', 'other')),
  height_cm numeric(5,1) check (height_cm between 50 and 300),
  weight_kg numeric(5,1) check (weight_kg between 20 and 400),
  activity_level activity_level default 'moderate',
  training_days_per_week int default 3 check (training_days_per_week between 0 and 7),
  dietary_preferences text[] default '{}',        -- e.g. {vegan, halal}
  budget_level int default 2 check (budget_level between 1 and 3),  -- 1=$ 2=$$ 3=$$$
  max_cook_minutes int default 30,
  -- computed daily targets (recalculated on profile change / training day)
  target_calories int,
  target_protein_g int,
  target_carbs_g int,
  target_fat_g int,
  onboarding_completed boolean default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- Allergen reference list ----------
create table public.allergens (
  id serial primary key,
  slug text unique not null,       -- 'peanut', 'tree_nut', 'dairy'...
  name text not null,
  is_top9 boolean default false    -- FDA top-9 major allergens
);

insert into public.allergens (slug, name, is_top9) values
  ('peanut', 'Peanut', true),
  ('tree_nut', 'Tree Nuts', true),
  ('dairy', 'Milk / Dairy', true),
  ('egg', 'Egg', true),
  ('wheat', 'Wheat', true),
  ('gluten', 'Gluten', false),
  ('soy', 'Soy', true),
  ('fish', 'Fish', true),
  ('shellfish', 'Crustacean Shellfish', true),
  ('sesame', 'Sesame', true),
  ('corn', 'Corn', false),
  ('nightshade', 'Nightshades', false),
  ('histamine', 'Histamine', false),
  ('fodmap', 'FODMAPs', false),
  ('sulfite', 'Sulfites', false),
  ('mustard', 'Mustard', false),
  ('celery', 'Celery', false),
  ('lupin', 'Lupin', false),
  ('mollusc', 'Molluscs', false),
  ('alpha_gal', 'Alpha-gal (red meat)', false);

-- ---------- User allergens (incl. custom) ----------
create table public.user_allergens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  allergen_id int references public.allergens(id),   -- null when custom
  custom_name text,                                  -- used when allergen_id is null
  severity severity_level not null default 'moderate',
  is_intolerance boolean default false,              -- intolerance vs true allergy
  notes text,
  created_at timestamptz not null default now(),
  check (allergen_id is not null or custom_name is not null)
);
create unique index user_allergens_unique_std on public.user_allergens(user_id, allergen_id) where allergen_id is not null;

-- ---------- Meal logs (the food side of the loop) ----------
create table public.meal_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  eaten_at timestamptz not null default now(),
  meal_type meal_type not null default 'snack',
  name text not null,
  -- ingredients as structured list so the correlation engine can match on them
  ingredients jsonb not null default '[]',  -- [{"name":"oats","allergen_slugs":[]}, ...]
  calories int check (calories >= 0),
  protein_g numeric(6,1) check (protein_g >= 0),
  carbs_g numeric(6,1) check (carbs_g >= 0),
  fat_g numeric(6,1) check (fat_g >= 0),
  fiber_g numeric(6,1) check (fiber_g >= 0),
  from_plan_id uuid,                        -- set when logged from a generated plan
  notes text,
  created_at timestamptz not null default now()
);
create index meal_logs_user_time on public.meal_logs(user_id, eaten_at desc);
create index meal_logs_ingredients on public.meal_logs using gin (ingredients jsonb_path_ops);

-- ---------- Workouts ----------
create table public.workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  started_at timestamptz not null default now(),
  workout_type workout_type not null default 'other',
  duration_minutes int check (duration_minutes between 1 and 600),
  intensity workout_intensity not null default 'moderate',
  notes text,
  created_at timestamptz not null default now()
);
create index workouts_user_time on public.workouts(user_id, started_at desc);

-- ---------- Symptom check-ins (the reaction side of the loop) ----------
create table public.symptom_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  occurred_at timestamptz not null default now(),
  symptoms symptom_type[] not null,
  severity severity_level not null default 'mild',
  during_or_after_exercise boolean default false,   -- EIA signal
  notes text,
  created_at timestamptz not null default now()
);
create index symptom_logs_user_time on public.symptom_logs(user_id, occurred_at desc);

-- ---------- AI meal plans ----------
create table public.meal_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  starts_on date not null,
  days int not null default 1 check (days between 1 and 14),
  status plan_status not null default 'active',
  -- full structured plan from Claude: days -> meals -> ingredients/macros
  plan jsonb not null,
  grocery_list jsonb,          -- generated + rebalanced on swaps
  generation_params jsonb,     -- targets/constraints used, for regeneration
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index meal_plans_user on public.meal_plans(user_id, starts_on desc);

alter table public.meal_logs
  add constraint meal_logs_from_plan_fk
  foreign key (from_plan_id) references public.meal_plans(id) on delete set null;

-- ---------- Daily metrics (weight, water, adherence) ----------
create table public.daily_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  date date not null,
  weight_kg numeric(5,1),
  water_ml int default 0 check (water_ml >= 0),
  is_training_day boolean default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, date)
);

-- ---------- Detected reaction patterns (correlation engine output) ----------
create table public.reaction_patterns (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  ingredient text not null,                 -- what keeps showing up
  symptom symptom_type not null,
  occurrence_count int not null,            -- times ingredient preceded symptom
  exposure_count int not null,              -- times ingredient was eaten at all
  window_minutes int not null default 180,  -- time window used
  exercise_linked boolean default false,    -- only fires around workouts (EIA)
  confidence numeric(3,2) check (confidence between 0 and 1),
  first_detected timestamptz not null default now(),
  last_updated timestamptz not null default now(),
  dismissed boolean default false,          -- user can dismiss false positives
  unique (user_id, ingredient, symptom, exercise_linked)
);

-- ============================================================
-- Correlation engine v1: time-window pattern surfacing
-- Finds ingredients eaten within N minutes before symptoms.
-- ============================================================
create or replace function public.detect_reaction_patterns(p_user_id uuid, p_window_minutes int default 180)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- only the owner may run it
  if p_user_id <> auth.uid() then
    raise exception 'not authorized';
  end if;

  insert into reaction_patterns
    (user_id, ingredient, symptom, occurrence_count, exposure_count, window_minutes, exercise_linked, confidence, last_updated)
  select
    p_user_id,
    ing.name,
    s.symptom,
    count(distinct sl.id)                          as occurrence_count,
    exp.exposure_count,
    p_window_minutes,
    bool_and(coalesce(sl.during_or_after_exercise, false)) as exercise_linked,
    least(1.0, round(count(distinct sl.id)::numeric / greatest(exp.exposure_count, 1), 2)) as confidence,
    now()
  from symptom_logs sl
  cross join lateral unnest(sl.symptoms) as s(symptom)
  join meal_logs ml
    on ml.user_id = sl.user_id
   and ml.eaten_at between sl.occurred_at - make_interval(mins => p_window_minutes) and sl.occurred_at
  cross join lateral jsonb_to_recordset(ml.ingredients) as ing(name text)
  join lateral (
    select count(*) as exposure_count
    from meal_logs ml2
    cross join lateral jsonb_to_recordset(ml2.ingredients) as ing2(name text)
    where ml2.user_id = p_user_id and lower(ing2.name) = lower(ing.name)
  ) exp on true
  where sl.user_id = p_user_id
  group by ing.name, s.symptom, exp.exposure_count
  having count(distinct sl.id) >= 2      -- at least 2 co-occurrences before surfacing
  on conflict (user_id, ingredient, symptom, exercise_linked)
  do update set
    occurrence_count = excluded.occurrence_count,
    exposure_count   = excluded.exposure_count,
    confidence       = excluded.confidence,
    last_updated     = now();
end;
$$;

-- ---------- Auto-create profile on signup ----------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- updated_at maintenance ----------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
create trigger meal_plans_touch before update on public.meal_plans for each row execute function public.touch_updated_at();
create trigger daily_metrics_touch before update on public.daily_metrics for each row execute function public.touch_updated_at();

-- ============================================================
-- Row-Level Security: users can only touch their own rows
-- ============================================================
alter table public.profiles enable row level security;
alter table public.user_allergens enable row level security;
alter table public.meal_logs enable row level security;
alter table public.workouts enable row level security;
alter table public.symptom_logs enable row level security;
alter table public.meal_plans enable row level security;
alter table public.daily_metrics enable row level security;
alter table public.reaction_patterns enable row level security;
alter table public.allergens enable row level security;

-- allergens list is public read-only reference data
create policy "allergens are readable by all users"
  on public.allergens for select to authenticated using (true);

create policy "own profile select" on public.profiles for select to authenticated using (id = auth.uid());
create policy "own profile update" on public.profiles for update to authenticated using (id = auth.uid());

create policy "own rows select" on public.user_allergens for select to authenticated using (user_id = auth.uid());
create policy "own rows insert" on public.user_allergens for insert to authenticated with check (user_id = auth.uid());
create policy "own rows update" on public.user_allergens for update to authenticated using (user_id = auth.uid());
create policy "own rows delete" on public.user_allergens for delete to authenticated using (user_id = auth.uid());

create policy "own rows select" on public.meal_logs for select to authenticated using (user_id = auth.uid());
create policy "own rows insert" on public.meal_logs for insert to authenticated with check (user_id = auth.uid());
create policy "own rows update" on public.meal_logs for update to authenticated using (user_id = auth.uid());
create policy "own rows delete" on public.meal_logs for delete to authenticated using (user_id = auth.uid());

create policy "own rows select" on public.workouts for select to authenticated using (user_id = auth.uid());
create policy "own rows insert" on public.workouts for insert to authenticated with check (user_id = auth.uid());
create policy "own rows update" on public.workouts for update to authenticated using (user_id = auth.uid());
create policy "own rows delete" on public.workouts for delete to authenticated using (user_id = auth.uid());

create policy "own rows select" on public.symptom_logs for select to authenticated using (user_id = auth.uid());
create policy "own rows insert" on public.symptom_logs for insert to authenticated with check (user_id = auth.uid());
create policy "own rows update" on public.symptom_logs for update to authenticated using (user_id = auth.uid());
create policy "own rows delete" on public.symptom_logs for delete to authenticated using (user_id = auth.uid());

create policy "own rows select" on public.meal_plans for select to authenticated using (user_id = auth.uid());
create policy "own rows insert" on public.meal_plans for insert to authenticated with check (user_id = auth.uid());
create policy "own rows update" on public.meal_plans for update to authenticated using (user_id = auth.uid());
create policy "own rows delete" on public.meal_plans for delete to authenticated using (user_id = auth.uid());

create policy "own rows select" on public.daily_metrics for select to authenticated using (user_id = auth.uid());
create policy "own rows insert" on public.daily_metrics for insert to authenticated with check (user_id = auth.uid());
create policy "own rows update" on public.daily_metrics for update to authenticated using (user_id = auth.uid());
create policy "own rows delete" on public.daily_metrics for delete to authenticated using (user_id = auth.uid());

create policy "own rows select" on public.reaction_patterns for select to authenticated using (user_id = auth.uid());
create policy "own rows update" on public.reaction_patterns for update to authenticated using (user_id = auth.uid());
-- inserts happen only via detect_reaction_patterns (security definer)
