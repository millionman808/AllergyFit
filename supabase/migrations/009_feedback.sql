-- ============================================================
-- In-app feedback. Users can write TO this table but never read from it:
-- feedback is for us, and one user must never see another's.
-- ============================================================
create table if not exists public.feedback (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete set null,
  kind        text not null check (kind in ('idea', 'problem', 'other')),
  message     text not null check (char_length(message) between 1 and 4000),
  -- Only filled when the user opts in to a reply.
  reply_email text,
  app_version text,
  build       text,
  device      text,
  os_version  text,
  created_at  timestamptz not null default now()
);
alter table public.feedback enable row level security;

-- Signed-in users may insert rows that are theirs. No select/update/delete
-- policy = the app can never read feedback back; only the service role can.
create policy "own feedback insert" on public.feedback
  for insert to authenticated
  with check (user_id = auth.uid());

create index if not exists feedback_created_at_idx on public.feedback (created_at desc);

-- ============================================================
-- In-app account deletion (App Store Guideline 5.1.1(v)).
-- security definer so it may delete from auth.users; scoped to auth.uid()
-- so a caller can only ever delete themselves. Every user table references
-- auth.users(id) on delete cascade, so profile, allergens, meals, symptoms,
-- plans and ai_usage go with it. Feedback is kept but anonymised (set null).
-- ============================================================
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;
revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
