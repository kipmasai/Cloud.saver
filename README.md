# Cloud Saver

Cloud Saver is a mobile-first personal cloud drive built with React, TypeScript, Vite and Supabase. It supports account registration/sign-in, private file uploads, download, rename, search/sort, share links, trash/restore, profile settings, support details and a responsive dashboard.

## Supabase project already configured

The included `.env.local` contains the Supabase project URL and publishable key you supplied. A publishable key is meant for browser use; **never add a Supabase secret/service-role key to frontend files or GitHub**. `.env.local` is excluded by `.gitignore`.

## 1. Set up the database and private bucket

1. Open the Supabase project at `https://supabase.com/dashboard/project/estnfzrfyqppzdlnohow`.
2. Open **SQL Editor** and run the complete script in `supabase/schema.sql`.
3. This creates `profiles`, `cloud_files`, `file_shares`, and `admin_users`, enables Row Level Security, creates owner-only policies, creates a private `cloud-files` Storage bucket with a 50 MB per-file limit, and installs a signup profile trigger.
4. Review the resulting policies in Supabase before uploading personal data. Keep the bucket private.

## 2. Deploy the secure share-link function

Public share viewers must not be given broad read access to private database rows or Storage objects. The `supabase/functions/download-shared/index.ts` Edge Function validates a share token and creates a short-lived signed download URL.

Install the Supabase CLI, sign in, link the existing project, and deploy the function:

```bash
supabase login
supabase link --project-ref estnfzrfyqppzdlnohow
supabase functions deploy download-shared --no-verify-jwt
```

Supabase supplies `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` to Edge Functions in its hosted environment. If deploying to another environment, set those as server-side secrets only. Never put the service-role key in `VITE_*` variables.

## 3. Run locally

Requires Node.js 20+.

```bash
npm install
npm run dev
```

For a production build:

```bash
npm run build
npm run preview
```

## 4. GitHub + Cloudflare Pages deployment

1. Create a **private** GitHub repository and upload the project. Do not commit `.env.local`; it is ignored by `.gitignore`.
2. In Cloudflare Dashboard, open **Workers & Pages → Create → Pages → Connect to Git** and choose the GitHub repository.
3. Use build command `npm run build` and output directory `dist`.
4. In Cloudflare Pages project settings, add build-time environment variables:
   - `VITE_SUPABASE_URL` = `https://estnfzrfyqppzdlnohow.supabase.co`
   - `VITE_SUPABASE_PUBLISHABLE_KEY` = the publishable key supplied to you
5. Set your production site URL under Supabase **Authentication → URL Configuration** as the Site URL and add your Cloudflare Pages URL to the allowed Redirect URLs. Add your local URL for development as needed.
6. Deploy the Supabase Edge Function separately using the CLI instructions above. Cloudflare Pages hosts the frontend; the existing Supabase project provides auth, database, storage and the share function.

For a React Router single-page app, add a file named `public/_redirects` containing `/* /index.html 200` before deployment. Cloudflare Pages will then route client-side URLs correctly.

## 5. Google sign-in (optional)

Email/password sign-in is implemented. Google sign-in is not shown as a working option because it needs OAuth configuration. To enable it, configure a Google OAuth client and Supabase Auth provider, set the authorized callback URL shown in Supabase, and add the production and local redirect URLs. Never fake a Google sign-in button without completing provider setup.

## 6. Admin access

The current Admin / Support area shows the administrator's contact details and setup notes; it is not a user-management console. The `admin_users` table is reserved for future server-authorized admin features. After registering your account, use Supabase SQL Editor to grant access to the specific UUID from Authentication → Users:

```sql
insert into public.admin_users (user_id, granted_by)
values ('YOUR-REGISTERED-USER-UUID', 'project-owner');
```

Do not grant admin privileges through editable profile metadata. Before adding destructive admin operations, enforce admin checks in server-side functions.

## Support and credits

- Creator: Mr Kïpmäsäï
- WhatsApp: +254 722 607044
- Email: mrkipmasai@gmail.com
- Support: sapportkipmasai254@gmail.com
- TikTok: @mr.kipmasai5
- Facebook: mrkipmasai
- YouTube: @MrKïpmäsäï-x9y
- Country: Kenya
- Footer: **Built with ❤️ in Kenya by Mr Kïpmäsäï 🇰🇪**

## Important production notes

- Storage quota display is currently a 1 GB informational default, not an enforced account quota. Actual plan limits depend on Supabase and must be configured/enforced server-side for production.
- File uploads are limited to 50 MB per file by the included bucket setup. Change the bucket limit only after checking the Supabase plan and application requirements.
- Email confirmation may be enabled in Supabase Auth. When enabled, new users must confirm their email before a session is issued.
- Apply and verify the SQL and Edge Function before using real private files. The source is prepared for your project, but this folder has not been deployed to GitHub or Cloudflare automatically.
