# Architecture

How Expenses Divider is built, run, and shipped. Who it is for and the quality bar: [product-context.md](./product-context.md). Product language: [domain-overview.md](./domain-overview.md) and [domain.md](./domain.md). Clone-and-run: [README.md](../README.md).

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
| i18n | Paraglide. UI in German and English. |
| Hosting | Vercel (`@sveltejs/adapter-vercel`) |
| Repo | GitHub |
| CI | GitHub Actions: `ci` on PRs and `main`; manual production migrate |
| Tests | None for now |

Local Supabase is optional. A hosted Supabase project is enough for development.

---

## Performance

The app should feel **fast**, including on **older phones**. Most people will use it on a phone, often on a slow connection.

A group page is a small amount of data; do not make it feel like a heavy SPA.

Prefer:

- Server-rendered pages and form actions (no extra client fetch to load a group)
- Little JavaScript in the browser
- Settlement math on the server
- No large client libraries unless a feature needs them

Speed is a reason for the BFF, Paraglide’s tree-shaken messages, and keeping locale out of a second navigation. If a choice is slower for no product gain, do not take it.

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

Policies follow the domain (phase 3 writes the SQL):

- A visitor sees a group only if this `auth.uid()` is allowed to (opened that public group, or is a private-group member by email).
- They cannot `SELECT` every public group. A policy that is true for all `access_mode = public` rows would leak every UUID. First open of `/g/[groupId]` records a **grant** for this user to this group; policies key off grants and identities.
- Writes match domain rules: recorded-by, and **creator powers** if this user is linked to the **creator member** (not to an Auth user on the group).

If SvelteKit used the pooler as table owner, RLS would not run. That is why the request path does not use that connection.

---

## Access

Domain rules for who may do what live in [domain.md](./domain.md). This section is how the server remembers that.

### Public group

The group URL is `/g/[groupId]`. `groupId` is a UUID. Treat it as a secret. There is no public list of groups.

Opening the URL is enough to load the group. No visible account. The anonymous Auth session is under the hood.

**Creator:** a **member**, not an Auth user. The group points at that member (for example Bob). Anyone whose identity is that member has full admin on the group (members and all expenses). Two browsers that both claim Bob both have admin.

**Who you are:** the first time they use a public group, they pick or add a member name. The server inserts `group_member_identities` (`auth.uid()` → that member in this group). Next visit, the session is enough: look up the link, skip the picker.

Two browsers can both link to Lucas. Both can edit expenses recorded as Lucas. If Lucas is the creator member, both have admin.

### Private group

Documented now; UI is after the public-group MVP.

Access: the visitor opens `/g/[groupId]` **and** is signed in with Google **and** that account’s email matches a member email on the group. Then they act as that member. The app does not send invitation mail. The creator shares the URL themselves.

Creating a private group requires Google sign-in.

### Google

There is no email/password. When a visible login exists, it is Google via Supabase Auth, optionally **linked** to the existing anonymous user so they keep the same member.

Public-group MVP needs **anonymous** Auth (Supabase URL + anon key). It does not need the Google provider until private groups.

---

## Routes

| Path | Purpose |
| --- | --- |
| `/` | Create a public group (MVP). Later: choose public vs private. |
| `/g/[groupId]` | The group: members, expenses, balances, settlement suggestion |

Locale is **not** part of the path. A shared group URL must not force the recipient’s UI language.

Settlement math is a pure TypeScript module used on the server, not a SQL view.

---

## Languages

The **product UI** is German (`de`) and English (`en`).

- If the visitor has saved a choice, use it.
- Else if `Accept-Language` prefers `de` or `en`, use that.
- Else **English**.

Persist an explicit choice in a cookie. A language switcher in the chrome is in scope for the UI phase.

Use [Paraglide](https://inlang.com/m/gerre34r/library-inlang-paraglideJs) with message files in the repo. Do not put `de` / `en` prefixes on `/g/[groupId]`.

Developer docs (this file, README, domain files) stay English.

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

How to run locally is in [README.md](../README.md).

---

## Deployment and migrations

GitHub is the source of truth. Vercel deploys from `main`.

Vercel does **not** run migrations at application startup.

Migrations live in `drizzle/` and are committed with the code that needs them. After merge:

1. Run the GitHub Actions workflow **Migrate production database** (manual). It uses the `DATABASE_URL` secret in the GitHub `production` environment.
2. Deploy or enable the code that depends on the new schema.

Prefer backwards-compatible migrations once real expense data exists (add before removing).

Custom domain: not now. Vercel can attach a domain later without changing this architecture.
