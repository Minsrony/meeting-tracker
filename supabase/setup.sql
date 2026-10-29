-- Meeting Action Tracker: database setup for a FRESH Supabase project.
-- Run once in the Supabase SQL editor. (The project this repo was built against already has all of this applied.)
--
-- ACCESS MODEL: open. Anyone who has the page link, or the publishable key, can read, add, edit and delete
-- every action in this one table. Nothing else in the project is exposed by these rules.

create table public.meeting_actions (
  id uuid primary key default gen_random_uuid(),
  action text not null check (char_length(action) between 1 and 200),
  owner text not null check (char_length(owner) between 1 and 40),
  due_date date not null,
  done boolean not null default false,
  is_example boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.meeting_actions enable row level security;

grant select, insert, update, delete on public.meeting_actions to anon, authenticated;

create policy "anyone can read actions" on public.meeting_actions
  for select to anon, authenticated using (true);
create policy "anyone can add actions" on public.meeting_actions
  for insert to anon, authenticated with check (true);
create policy "anyone can update actions" on public.meeting_actions
  for update to anon, authenticated using (true) with check (true);
create policy "anyone can delete actions" on public.meeting_actions
  for delete to anon, authenticated using (true);

-- Live updates: push row changes to open pages.
alter publication supabase_realtime add table public.meeting_actions;

-- To lock the table down again, drop the four policies above and revoke the grants:
--   revoke all on public.meeting_actions from anon, authenticated;
-- A version of the app with email sign-in and an allowed-domain check is in the Git history (commit 253e296).
