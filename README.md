# Expenses Divider

The first technical milestone for Expenses Divider: a SvelteKit app hosted on Vercel whose button increments a shared Postgres counter in Supabase.

## Stack

- SvelteKit and TypeScript
- Tailwind CSS and shadcn-svelte
- Supabase Postgres
- Drizzle ORM and Drizzle Kit
- Vercel deployment

## Local setup

1. Copy `.env.example` to `.env` and replace `DATABASE_URL` with the Supabase transaction-pooler connection string.
2. Run `npm install`.
3. Run `npm run db:generate` then `npm run db:migrate` to create the `demo_counter` table.
4. Run `npm run dev` and open the displayed local URL.

For the initial hosted database, use the idempotent `supabase/bootstrap.sql` in the Supabase SQL Editor. It creates the counter and marks the committed Drizzle migration as applied. This workspace's Node runtime cannot run Drizzle Kit because of an OS-level user-profile error; the SQL is provided so provisioning is not blocked.

## Commands

- `npm run check` — TypeScript and Svelte checking
- `npm run lint` — formatting and linting
- `npm run db:generate` — create a committed Drizzle migration
- `npm run db:migrate` — apply migrations
- `npm run build` — production build

## Deployment

Set `DATABASE_URL` as an environment variable in Vercel for Preview and Production. The value is server-only and must never be prefixed with `PUBLIC_`.
