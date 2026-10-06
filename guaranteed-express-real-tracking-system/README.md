# Guaranteed Express Delivery Services — Real Tracking Starter

This is a production-oriented starter using Supabase Auth + Postgres and a static frontend.

## 1. Create the database
Create a Supabase project, open SQL Editor, and run `schema.sql`.

## 2. Create the admin account
In Supabase Authentication, create an email/password user. Copy that user's UUID.
Then run:
`insert into public.admin_profiles(user_id) values ('YOUR-USER-UUID');`

Do not put a service-role key in the website. The browser should use only the project's publishable/anon key.

## 3. Configure the frontend
Copy `config.js.example` to `config.js`.
Set:
- SUPABASE_URL
- SUPABASE_PUBLISHABLE_KEY

## 4. Test locally
Serve the folder through a local web server (rather than double-clicking the HTML file), e.g.:
`python3 -m http.server 8080`
Then open `http://localhost:8080`.

## 5. Deploy
Netlify, Cloudflare Pages, or GitHub Pages can host the static files. If using a build/deploy system, keep config values in the host's environment/configuration where appropriate.

## Security
The public site does NOT select directly from the shipments table. It calls `track_shipment(tracking_number)`, which returns only the fields intended for tracking. RLS blocks direct anonymous access to the underlying tables.

The admin uses Supabase Auth and an admin_profiles allow-list. Keep database policies enabled and never expose a Supabase service-role secret in browser code.

This project is for an independently operated/fictional carrier brand. Do not use it to impersonate another carrier, collect payment credentials, or create fraudulent shipping records.
