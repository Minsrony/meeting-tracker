# Meeting Action Tracker

A small static web app for a team that keeps forgetting agreed actions. Add an action with an owner and a due date, see actions grouped by owner with a tick box, and watch open, done and overdue counts update live. Overdue actions show in red.

It is a single `index.html` with no build step. Data and sign-in live in Supabase.

## Files

| File | Purpose |
| --- | --- |
| `index.html` | The whole app: sign-in, tracker, user management. |
| `vercel.json` | Security headers and a Content Security Policy for Vercel. |
| `supabase/setup.sql` | Tables, functions, access rules and first users for a fresh Supabase project. |
| `.gitignore` | Keeps local Vercel and env files out of Git. |

## Deploy to Vercel

1. In Vercel choose **Add New, Project** and import this GitHub repository.
2. Set **Framework Preset** to **Other**. Leave Build Command, Output Directory and Install Command empty.
3. Deploy. Vercel serves `index.html` from the repository root.

No environment variables are needed.

## Supabase settings to check (dashboard, Authentication)

- **Turn off "Allow new users to sign up".** Accounts are created by admins inside the app, so public sign-up is not needed. Anyone who signs up on their own gets no access to the data, but they would still clutter your user list and could take a username before you do.
- **Turn on leaked password protection** if your plan offers it. It rejects passwords found in known breaches.
- Email confirmation and email templates do not matter here, because accounts are created already confirmed and there is no email flow.

## Signing in

People sign in with a **username** and password. Supabase Auth stores each account in its built-in `auth.users` table with the password hashed (bcrypt). Behind the scenes the username is turned into an internal address, `<username>@tracker.example`. That is a reserved domain nobody can register, so there is no mailbox to take over and no password-reset email. Passwords are reset by an admin.

`public.profiles` links to `auth.users` and holds the username, display name, role (`admin` or `member`) and whether the person still has to choose their own password.

The first users are `priya`, `sam` and `marcus`, all admins, each with the password `password`. **Each is made to choose a new password the first time they sign in.** Until they do, anyone who knows the username can get in, so have people sign in soon after deploying, or reset the default accounts you do not need.

## Managing users

Admins see a **Users** button at the top of the page. From there they can:

- **Add a user:** username, optional display name, an initial password and a role. The person is asked to choose their own password at first sign-in.
- **Reset a password:** set a temporary one. The person is signed out everywhere and must choose a new one next time.
- **Remove a user.** Admins cannot remove or reset their own account from this screen. Everyone can use **Change password** in the header.

Every account created through the app is a normal Supabase Auth user, so it also shows up in the dashboard under Authentication, Users.

## Who can see and edit actions

Only signed-in people who have a row in `public.profiles`. The Supabase URL and publishable key are visible in the page source, which is fine: the database rules (row-level security) refuse anyone who is not signed in, and anyone who signs in without a profile sees nothing. The three admin functions check for the admin role inside the database, not just in the page.

Other tables in the same Supabase project have their own rules, and the publishable key can use anything those rules make public.

## Notes

- Never put a Supabase `service_role` or secret key in this repository.
- If you change the Supabase project URL, update both `index.html` and the `connect-src` entry in `vercel.json`.
- To preview locally, run `npx serve .` in this folder.
- Earlier versions are in the Git history: open access (`ba58855`) and email sign-in limited to one domain (`253e296`).
