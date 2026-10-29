-- Meeting Action Tracker: database setup for a FRESH Supabase project.
-- Run once in the Supabase SQL editor. (The project this repo was built against already has all of this applied.)
--
-- ACCESS MODEL: sign-in required.
--   * People sign in with a username and password. Supabase Auth stores the account in auth.users
--     (password hashed with bcrypt) under the internal address <username>@tracker.example.
--   * public.profiles holds one row per app user and links to auth.users.
--   * Only signed-in users who have a profile row can read or change meeting_actions.
--   * Admins add users, reset passwords and remove users from the app's Users screen.

-- 0. Private schema (not exposed through the Supabase API) ------------------------------------------
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- 1. profiles: one row per app user, linked to Supabase's built-in auth.users --------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9][a-z0-9._-]{2,29}$'),
  display_name text not null check (char_length(display_name) between 1 and 40),
  role text not null default 'member' check (role in ('admin', 'member')),
  must_change_password boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (must_change_password) on public.profiles to authenticated;

-- 2. Helpers used by the access rules -------------------------------------------------------------------
create or replace function private.is_app_user()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.profiles where id = (select auth.uid())); $$;

create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'); $$;

revoke all on function private.is_app_user() from public, anon;
revoke all on function private.is_admin() from public, anon;
grant execute on function private.is_app_user() to authenticated;
grant execute on function private.is_admin() to authenticated;

-- 3. Create a user: auth.users row (bcrypt cost 10), email identity, and profile ------------------------
create or replace function private.create_user(
  p_username text, p_password text, p_role text default 'member', p_display_name text default null
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_id uuid := gen_random_uuid();
  v_username text := lower(btrim(coalesce(p_username, '')));
  v_email text;
  v_name text;
begin
  if v_username !~ '^[a-z0-9][a-z0-9._-]{2,29}$' then
    raise exception 'Usernames use 3 to 30 letters, numbers, dots, dashes or underscores.';
  end if;
  if p_password is null or char_length(p_password) < 8 or char_length(p_password) > 72 then
    raise exception 'Passwords must be 8 to 72 characters.';
  end if;
  if p_role is null or p_role not in ('admin', 'member') then
    raise exception 'Role must be admin or member.';
  end if;
  v_email := v_username || '@tracker.example';
  if exists (select 1 from public.profiles where username = v_username)
     or exists (select 1 from auth.users where lower(email) = v_email) then
    raise exception 'That username is already taken.';
  end if;
  v_name := coalesce(nullif(btrim(p_display_name), ''), initcap(v_username));
  if char_length(v_name) > 40 then
    raise exception 'Display names can be up to 40 characters.';
  end if;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', v_email,
    extensions.crypt(p_password, extensions.gen_salt('bf', 10)), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('username', v_username), now(), now(),
    '', '', '', ''
  );

  insert into auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (
    gen_random_uuid(), v_id::text, v_id,
    jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true, 'phone_verified', false),
    'email', now(), now(), now()
  );

  insert into public.profiles (id, username, display_name, role, must_change_password)
  values (v_id, v_username, v_name, p_role, true);

  return v_id;
end;
$$;
revoke all on function private.create_user(text, text, text, text) from public, anon, authenticated;

-- 4. Admin-only functions the web app calls ---------------------------------------------------------------
create or replace function public.admin_create_user(
  p_username text, p_password text, p_role text default 'member', p_display_name text default null
) returns uuid
language plpgsql security definer set search_path = ''
as $$
begin
  if not (select private.is_admin()) then
    raise exception 'Only admins can add users.' using errcode = '42501';
  end if;
  return private.create_user(p_username, p_password, p_role, p_display_name);
end;
$$;

create or replace function public.admin_set_password(p_user_id uuid, p_password text)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not (select private.is_admin()) then
    raise exception 'Only admins can reset passwords.' using errcode = '42501';
  end if;
  if p_user_id = (select auth.uid()) then
    raise exception 'Use Change password for your own account.';
  end if;
  if p_password is null or char_length(p_password) < 8 or char_length(p_password) > 72 then
    raise exception 'Passwords must be 8 to 72 characters.';
  end if;
  update auth.users
     set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf', 10)), updated_at = now()
   where id = p_user_id;
  if not found then
    raise exception 'User not found.';
  end if;
  update public.profiles set must_change_password = true where id = p_user_id;
  delete from auth.sessions where user_id = p_user_id;   -- sign them out everywhere
end;
$$;

create or replace function public.admin_delete_user(p_user_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not (select private.is_admin()) then
    raise exception 'Only admins can remove users.' using errcode = '42501';
  end if;
  if p_user_id = (select auth.uid()) then
    raise exception 'You cannot remove your own account.';
  end if;
  delete from auth.users where id = p_user_id;           -- cascades to profile, identity and sessions
  if not found then
    raise exception 'User not found.';
  end if;
end;
$$;

revoke all on function public.admin_create_user(text, text, text, text) from public, anon, authenticated;
revoke all on function public.admin_set_password(uuid, text) from public, anon, authenticated;
revoke all on function public.admin_delete_user(uuid) from public, anon, authenticated;
grant execute on function public.admin_create_user(text, text, text, text) to authenticated;
grant execute on function public.admin_set_password(uuid, text) to authenticated;
grant execute on function public.admin_delete_user(uuid) to authenticated;

-- 5. profiles rules ------------------------------------------------------------------------------------
create policy "app users can read profiles" on public.profiles
  for select to authenticated using ((select private.is_app_user()));
create policy "users can clear their own password flag" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()) and must_change_password = false);

-- 6. The actions table and its rules --------------------------------------------------------------------
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
grant select, insert, update, delete on public.meeting_actions to authenticated;

create policy "signed-in users can read actions" on public.meeting_actions
  for select to authenticated using ((select private.is_app_user()));
create policy "signed-in users can add actions" on public.meeting_actions
  for insert to authenticated with check ((select private.is_app_user()));
create policy "signed-in users can update actions" on public.meeting_actions
  for update to authenticated using ((select private.is_app_user())) with check ((select private.is_app_user()));
create policy "signed-in users can delete actions" on public.meeting_actions
  for delete to authenticated using ((select private.is_app_user()));

-- Live updates: push row changes to open pages (row-level security still decides who receives them).
alter publication supabase_realtime add table public.meeting_actions;

-- 7. First users --------------------------------------------------------------------------------------------
-- Everyone starts with the password 'password' and is asked to choose their own at first sign-in.
-- Run these once, then change the usernames, or delete this section and add people from the app instead.
select private.create_user('priya',  'password', 'admin', 'Priya');
select private.create_user('sam',    'password', 'admin', 'Sam');
select private.create_user('marcus', 'password', 'admin', 'Marcus');

-- Optional: the example actions shown in the app
insert into public.meeting_actions (action, owner, due_date, done, is_example, created_at) values
  ('Send the revised timeline to the client', 'Priya', current_date - 2, false, true, now()),
  ('Book a room for next week''s review', 'Priya', current_date + 1, false, true, now() + interval '1 millisecond'),
  ('Update the onboarding checklist', 'Priya', current_date - 4, true, true, now() + interval '2 milliseconds'),
  ('Confirm the vendor quote before it expires', 'Marcus', current_date - 1, false, true, now() + interval '3 milliseconds'),
  ('Draft the budget summary for sign-off', 'Marcus', current_date + 2, false, true, now() + interval '4 milliseconds'),
  ('Share the meeting notes with the wider team', 'Sam', current_date, true, true, now() + interval '5 milliseconds'),
  ('Review the draft policy and send comments', 'Sam', current_date + 6, false, true, now() + interval '6 milliseconds');
