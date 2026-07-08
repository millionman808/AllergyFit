-- One weekly plan per user per week start; enables upsert sync from the app
alter table public.meal_plans
  add constraint meal_plans_user_week unique (user_id, starts_on);
