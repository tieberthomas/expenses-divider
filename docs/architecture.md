# Architecture

How Expenses Divider is built, run, and shipped.

---

## Stack

| Concern | Choice |
| --- | --- |
| App | SvelteKit 2, Svelte 5, TypeScript |
| UI | Tailwind CSS 4, shadcn-svelte, Lucide |
| Database | Supabase Postgres |
| ORM / migrations | Drizzle ORM, Drizzle Kit |
| Auth | Supabase Auth: anonymous sessions (under the hood) and Google (when a login is required) |
| Email | None. The app does not send mail. |
| i18n | Paraglide (see [Languages](#languages)) |
| Hosting | Vercel (`@sveltejs/adapter-vercel`) |
| Repo | GitHub |
| CI | GitHub Actions: `ci` on PRs and `main`; manual production migrate |
| Tests | None for now |

Local Supabase is optional. A hosted Supabase project is enough for development.

---

## Performance

Quality bar (fast, phones): [product-context.md](./product-context.md).

How:

- Server-rendered pages and form actions (no extra client fetch to load a group)
- Little JavaScript in the browser
- Settlement math on the server
- No large client libraries unless a feature needs them

---

## Request path

```
Browser  →  SvelteKit (Vercel)  →  Postgres (as that visitor’s Auth user)
                 │                         RLS applies
                 └── Supabase Auth (anonymous session, or Google)
```

SvelteKit is the public API. Pages load in server `load` functions. Writes go through form actions.

On first visit, the server signs the browser in **anonymously** (no UI). That session is a real `auth.users` row. `auth.uid()` is what RLS uses. Google later can be linked to the same user.

**Group data on the request path** uses the Supabase server client **with that user’s JWT** (the anon/authenticated key, never `service_role`). Postgres then applies RLS. Do not use Drizzle with `DATABASE_URL` for those queries: that role is table owner and **bypasses** RLS.

`DATABASE_URL` is private and only for **migrations** (Drizzle Kit) and other break-glass admin. Never prefix it with `PUBLIC_`. Transaction pooler, port 6543, `prepare: false`.

The browser still should not query tables itself (performance: one round trip, little JS). The anon key will exist for Auth; **RLS is what stops that key from dumping the database.**

Never use the Supabase `service_role` key on the request path.

---

## Row Level Security

Every application table has RLS enabled. **Policies are real and enforced** for `anon` and `authenticated`. Request-path access must succeed or fail through those policies, not around them.

Who may do what is [domain.md](./domain.md). Policies implement that with `auth.uid()`, **grants**, and **identities**.

A policy that is true for every public group would leak every UUID. First open of `/g/[groupId]` records a **grant** for this user to this group. Policies key off grants and identities, not `access_mode = public`.

If SvelteKit used the pooler as table owner, RLS would not run. That is why the request path does not use that connection.

---

## Access (implementation)

Who may do what: [domain.md](./domain.md).

- Group URL: `/g/[groupId]`. UUID is a secret. No list of all groups.
- First visit: anonymous Auth (no UI). `auth.uid()` is the principal.
- First open of a public group: insert a **grant** `(auth.uid(), group_id)`.
- After they pick a name: `group_member_identities` (`auth.uid()` → member). Return visits use the session.
- Creator admin in RLS: identity for the group’s **creator member**.
- Private groups: Google session; member email matches. Link the anonymous user when they sign in with Google.
- Public-group MVP: anonymous Auth (URL + anon key). Google provider later.

---

## Routes

| Path | Purpose |
| --- | --- |
| `/` | Create a public group (MVP). Later: choose public vs private. |
| `/g/[groupId]` | The group: members, expenses, balances, settlement suggestion |

Settlement math is a pure TypeScript module used on the server, not a SQL view.

---

## Languages

Which languages and default: [product-context.md](./product-context.md).

Use [Paraglide](https://inlang.com/m/gerre34r/library-inlang-paraglideJs). Persist a chosen locale in a cookie; otherwise use `Accept-Language` if it is `de` or `en`. Do not put `de` / `en` in the path (a shared `/g/[groupId]` must not force language).

---

## Environment

### App (server)

| Variable | When |
| --- | --- |
| `DATABASE_URL` | Migrations only. Transaction pooler (Connect → ORMs → Drizzle). |
| `PUBLIC_SUPABASE_URL` | Always. Auth + user-scoped data access (RLS). |
| `PUBLIC_SUPABASE_ANON_KEY` | Always. Never `service_role`. |

### Google (later)

| Variable | When |
| --- | --- |
| Google provider in the Supabase project | Private groups / visible sign-in |

Vercel gets `DATABASE_URL` (migrate workflow / Kit) plus the public Supabase URL and anon key (the app).

---

## Deployment and migrations

GitHub is the source of truth. Vercel deploys from `main`.

Vercel does **not** run migrations at application startup.

Migrations live in `drizzle/` and are committed with the code that needs them. After merge:

1. Run the GitHub Actions workflow **Migrate production database** (manual). It uses the `DATABASE_URL` secret in the GitHub `production` environment.
2. Deploy or enable the code that depends on the new schema.

Prefer backwards-compatible migrations once real expense data exists (add before removing).

Vercel can attach a custom domain later without changing this architecture.
