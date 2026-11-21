# Expenses Divider

A web app for splitting travel costs effortlessly.

## Docs

- [Product context](docs/product-context.md) — who it is for, devices, languages, quality bar
- [Domain overview](docs/domain-overview.md) — short walkthrough
- [Domain](docs/domain.md) — terms and rules
- [Architecture](docs/architecture.md) — how it is built and shipped
- [Implementation plan](docs/implementation-plan.md) — phases and working decisions

## Local setup

Node 22.

1. Copy `.env.example` to `.env`. Set `DATABASE_URL` (migrations) plus `PUBLIC_SUPABASE_URL` and `PUBLIC_SUPABASE_ANON_KEY`. Enable anonymous sign-in in the Supabase project.
2. Run `npm install`.
3. Run `npm run db:migrate`.
4. Run `npm run dev` and open the displayed local URL.
