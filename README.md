# Expenses Divider

A web app for splitting travel costs. Product language: [domain overview](docs/domain-overview.md). How the system is built: [architecture](docs/architecture.md).

The UI is German and English. These docs are English.

## Local setup

Node 22.

1. Copy `.env.example` to `.env`. Set `DATABASE_URL` (migrations) plus `PUBLIC_SUPABASE_URL` and `PUBLIC_SUPABASE_ANON_KEY`. Enable anonymous sign-in in the Supabase project.
2. Run `npm install`.
3. Run `npm run db:migrate`.
4. Run `npm run dev` and open the displayed local URL.
