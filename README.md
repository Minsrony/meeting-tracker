# Meeting Action Tracker

A small static web app for a team that keeps forgetting agreed actions. Add an action with an owner and a due date, see actions grouped by owner with a tick box, and watch open, done and overdue counts update live. Overdue actions show in red.

It is a single `index.html` with no build step and no sign-in. Data lives in Supabase.

## Files

| File | Purpose |
| --- | --- |
| `index.html` | The whole app. |
| `vercel.json` | Security headers and a Content Security Policy for Vercel. |
| `supabase/setup.sql` | Table, access rules and live-update setup for a fresh Supabase project. |
| `.gitignore` | Keeps local Vercel and env files out of Git. |

## Deploy to Vercel

1. In Vercel choose **Add New, Project** and import this GitHub repository.
2. Set **Framework Preset** to **Other**. Leave Build Command, Output Directory and Install Command empty.
3. Deploy. Vercel serves `index.html` from the repository root.

No environment variables are needed. There is nothing to configure in Supabase's Authentication settings either, because the app does not sign anyone in.

## Who can see and edit actions

Anyone who has the link. The Supabase URL and publishable key are visible in the page source, and the database rules allow that key to read, add, edit and delete every row in `meeting_actions`. That is the only table those rules touch.

What that means in practice:

- Share the link only with people you are happy to have editing the list.
- Anyone who finds the link, or uses the key directly, can also delete every action or fill the table with junk.
- To recover from a mess, restore from a Supabase backup or re-run the example inserts.

To lock it down later, drop the four `anyone can ...` policies and revoke the grants (the bottom of `supabase/setup.sql` shows how). A version with email sign-in limited to one email domain is in the Git history at commit `253e296`.

## Notes

- Never put a Supabase `service_role` or secret key in this repository.
- If you change the Supabase project URL, update both `index.html` and the `connect-src` entry in `vercel.json`.
- To preview locally, run `npx serve .` in this folder.
