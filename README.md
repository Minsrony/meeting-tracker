# Meeting Action Tracker

A small static web app for a team that keeps forgetting agreed actions. Add an action with an owner and a due date, see actions grouped by owner with a tick box, and watch open, done and overdue counts update live. Overdue actions show in red.

It is a single `index.html` with no build step. Data lives in Supabase, and people sign in with an email address on an allowed domain.

## Files

| File | Purpose |
| --- | --- |
| `index.html` | The whole app: sign-in, tracker, Supabase client. |
| `vercel.json` | Security headers and a Content Security Policy for Vercel. |
| `supabase/setup.sql` | Table, access rules and live-update setup for a fresh Supabase project. |
| `.gitignore` | Keeps local Vercel and env files out of Git. |

## Deploy to Vercel

1. In Vercel choose **Add New, Project** and import this GitHub repository.
2. Set **Framework Preset** to **Other**. Leave Build Command, Output Directory and Install Command empty.
3. Deploy. Vercel serves `index.html` from the repository root.

## Supabase settings to check (Authentication section of the dashboard)

- **Confirm email must stay ON.** Access is limited by email domain, and confirmation is what proves a person owns the mailbox. With it off, anyone could sign up as `someone@yourdomain.com`.
- **Site URL and Redirect URLs:** set the Site URL to your Vercel address (for example `https://meeting-tracker.vercel.app`) and add the same address under Redirect URLs. Confirmation and password reset emails link back there. Add preview or custom domains here too.
- **Email sending:** Supabase's built-in sender is limited to a few emails per hour. For a team, add your own SMTP provider under Authentication, Emails, SMTP settings.
- **Minimum password length:** the page asks for 8 characters. You can raise it in Authentication settings.

## Who can sign in

Only confirmed accounts whose email domain is listed in `private.allowed_domains` can read or change actions. Everyone else, including requests using only the publishable key, is refused by the database.

```sql
-- add a domain
insert into private.allowed_domains (domain) values ('example.com');

-- remove a domain
delete from private.allowed_domains where domain = 'example.com';
```

`EMAIL_DOMAIN_HINT` near the top of the script in `index.html` only controls the hint text and the sign-up check on the form. Update it if you change domains.

## Notes

- The project URL and publishable key in `index.html` are meant to be public. The access rules in `supabase/setup.sql` are what protect the data, so do not weaken them.
- Never put a Supabase `service_role` or secret key in this repository.
- If you change the Supabase project URL, update both `index.html` and the `connect-src` entry in `vercel.json`.
- To preview locally, run `npx serve .` in this folder. Add `http://localhost:3000` to the Supabase Redirect URLs if you want email links to work locally.
