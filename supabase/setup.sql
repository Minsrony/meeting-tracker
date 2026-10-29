-- Meeting Action Tracker: database setup for a FRESH Supabase project.
-- Run once in the Supabase SQL editor. (The project this repo was built against already has all of this applied.)

-- 1. The actions table ------------------------------------------------------------------
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
revoke all on public.meeting_actions from anon, authenticated;

-- 2. Who is allowed in ------------------------------------------------------------------
-- A private schema is not exposed through the Supabase API.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create table private.allowed_domains (
  domain text primary key check (domain = lower(domain) and position('@' in domain) = 0)
);
alter table private.allowed_domains enable row level security;
revoke all on private.allowed_domains from public, anon, authenticated;

-- Add or change the allowed email domains here:
insert into private.allowed_domains (domain) values ('thakralone.com');

-- True only for a signed-in user whose email is CONFIRMED and whose domain is on the list.
create or replace function private.is_team_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.users u
    join private.allowed_domains d on d.domain = lower(split_part(u.email, '@', 2))
    where u.id = (select auth.uid())
      and u.email_confirmed_at is not null
  );
$$;
revoke all on function private.is_team_member() from public, anon;
grant execute on function private.is_team_member() to authenticated;

-- Lets the page ask "am I allowed in?" so it can show a clear message.
create or replace function public.am_i_team_member()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$ select private.is_team_member(); $$;
revoke all on function public.am_i_team_member() from public, anon;
grant execute on function public.am_i_team_member() to authenticated;

-- 3. Row-level security: the publishable (anon) key gets nothing, team members get everything
grant select, insert, update, delete on public.meeting_actions to authenticated;

create policy "team members can read actions" on public.meeting_actions
  for select to authenticated using ((select private.is_team_member()));
create policy "team members can add actions" on public.meeting_actions
  for insert to authenticated with check ((select private.is_team_member()));
create policy "team members can update actions" on public.meeting_actions
  for update to authenticated using ((select private.is_team_member())) with check ((select private.is_team_member()));
create policy "team members can delete actions" on public.meeting_actions
  for delete to authenticated using ((select private.is_team_member()));

-- 4. Live updates: push row changes to open pages (RLS still decides who receives them)
alter publication supabase_realtime add table public.meeting_actions;
