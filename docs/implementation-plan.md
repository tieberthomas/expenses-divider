# Implementation plan

This is the working plan for building Expenses Divider. Execute it in order. Product intent lives in [product-context.md](./product-context.md). Do not invent features that are not in that brief or in the working decisions below.

The existing repo is a rough MVP of stack and schema. Most of it will be reworked. Keep what still matches this plan; replace what does not.

## How to execute

Each phase produces artifacts. A phase is done when those artifacts exist and match the product context.

| Phase | Status | Goal | Artifacts |
| --- | --- | --- | --- |
| 1 | **Done** | Shared language for the product | [domain-overview.md](./domain-overview.md), [domain.md](./domain.md) |
| 2 | Not started | Settled stack, architecture, local setup, deployment | `docs/architecture.md` (update `README.md` to match) |
| 3 | Not started | Data model, RLS, Drizzle schema, migration | `docs/data-model.md`, `src/lib/server/db/schema.ts`, a new Drizzle migration |
| 4 | Not started | Rough UI/server MVP of the core travel split | Working group create/view/add-expense/balances flow |

Later phases may rewrite earlier docs if a decision changes. Keep the docs the source of truth. Phase 1 is finished; later phases should follow those two domain files, not re-draft the product language from this plan’s original phase 1 checklist.

## Working decisions

These resolve open points in the brief. Change them here if they are wrong; then continue.

1. **Link groups need no login.** Creating a link group, opening it, adding members, and adding expenses works with only the URL.
2. **Google sign-in is required for private groups** (create, accept invite, add expenses). There is never email/password.
3. **Phase 4 MVP is link groups only.** Private groups and email invites are specified in domain and data model, but not built in the first UI.
4. **Members are named people.** A member can exist before anyone logs in. Google identity can later be linked to a member.
5. **One currency per group.** No currency conversion.
6. **Money is stored as integer minor units** (cents). Display uses the group currency.
7. **Settlement is computed, not recorded, in the MVP.** The app shows balances and a minimized list of suggested repayments. Marking a repayment as paid is out of the first MVP.
8. **Anyone with a link-group URL can edit or delete expenses and members** in the MVP. Private-group permissions will be stricter when that UI exists.
9. **The SvelteKit server is the only database client.** The browser does not use the Supabase anon key to read or write tables. RLS stays enabled as a safety net (deny by default).
10. **PWA / native app and a custom domain are later.** Deploy the web app on Vercel first.
11. **No automated tests** until the owner asks for them. CI keeps typecheck, lint, and build.

## Current repo (starting point)

Already in place and should be treated as the default unless phase 2 or 3 replaces it:

- SvelteKit, TypeScript, Tailwind CSS 4, shadcn-svelte (vega / neutral), Lucide
- `@sveltejs/adapter-vercel`
- Drizzle ORM + Drizzle Kit, `postgres` driver, transaction pooler (`prepare: false`)
- Tables: `groups`, `group_members`, `group_member_identities`, `expenses`, `expense_shares`
- RLS enabled on all app tables, with no client policies yet
- GitHub Actions: `ci` on pull requests and `main`; manual **Migrate production database** workflow
- Landing page copy only; no group UI yet

`created_by_user_id` currently requires an `auth.users` row. That conflicts with decision 1 (create a link group without login). Phase 3 must fix this.

---

## Phase 1 — Document the domain

**Status: done.**

**Outputs:**

- [domain-overview.md](./domain-overview.md) — short walkthrough of the product in domain language
- [domain.md](./domain.md) — detailed terms and rules

These two files are the domain source of truth. Later phases should follow them. If they disagree with this plan’s working decisions or with [product-context.md](./product-context.md), update those documents to match the domain files.

---

## Phase 2 — Stack, architecture, environment, deployment

**Goal:** Settle and write down how the system is built, run locally, and shipped. Prefer the current repo; only change it when the product decisions require it.

**Write:** `docs/architecture.md`  
**Also:** keep `README.md` as the short “how do I run this?” version of the same facts.

### Stack (settled unless this phase finds a blocker)

| Concern | Choice |
| --- | --- |
| App | SvelteKit + TypeScript, Svelte 5 |
| UI | Tailwind CSS 4 + shadcn-svelte + Lucide |
| Database | Supabase Postgres |
| ORM / migrations | Drizzle ORM + Drizzle Kit |
| Auth | Supabase Auth, Google provider only (used when a login is required) |
| Email | Not in phase 4; private-group invites will need a mail provider later (Supabase Auth or transactional email) |
| Hosting | Vercel (adapter already in the project) |
| Repo | GitHub |
| CI | Existing GitHub Actions (`ci`, manual production migrate) |
| Tests | None for now |

### Architecture to document

```
Browser  →  SvelteKit (Vercel)  →  Postgres (Supabase)
                 │
                 └── Supabase Auth (Google) when the user signs in
```

Document these rules:

- All reads and writes of group data go through SvelteKit server load functions and form actions (or server APIs).
- `DATABASE_URL` is private. Never `PUBLIC_`.
- Use the Supabase transaction pooler for the app (port 6543, no prepared statements).
- RLS is enabled; the app role used from the server is trusted. Browser roles get no policies until we deliberately add them.
- Link-group authorization is “knowledge of the UUID in the URL.” Treat UUIDs as secrets. Do not list all groups on a public index.
- Private-group authorization is “Google user is an invited member.” Implementation can wait until after the link-group MVP, but the architecture doc should describe it.
- Group routes look like `/g/[groupId]` (final path can be chosen in this phase; pick one and stick to it).
- Settlement math lives in a pure server-side module, not in SQL views, for the first version.

### Dev environment to document

1. Node 22 (matches CI).
2. Copy `.env.example` → `.env`.
3. Supabase project for development (can be a hosted free project; local Supabase is optional, not required).
4. `npm install`, `npm run db:migrate`, `npm run dev`.
5. Commands: `check`, `lint`, `ci`, `db:generate`, `db:migrate`, `db:studio`.
6. Google OAuth is not required to work on the link-group MVP. Document how to enable it when private groups or “claim this member” is built.

### Deployment to document

1. GitHub is the source of truth; Vercel deploys from `main`.
2. Vercel env: `DATABASE_URL` (and later Supabase Auth URL/keys for Google).
3. Vercel does **not** run migrations on startup.
4. After merging a schema change: run the manual **Migrate production database** workflow (GitHub `production` environment + `DATABASE_URL` secret), then deploy or enable the new code.
5. Prefer backwards-compatible migrations once real data exists.
6. Custom domain: not now. Note that Vercel can attach a domain later without changing the app architecture.

**Done when:** `docs/architecture.md` and `README.md` agree, and a new developer can set up the project from the README alone.

---

## Phase 3 — Data model, RLS, schema, migration

**Goal:** A model that matches the domain, including RLS. Implement it in Drizzle and ship a migration. Document it.

**Write:** `docs/data-model.md`  
**Change:** `src/lib/server/db/schema.ts`  
**Generate:** a new Drizzle migration (do not hand-edit old applied migrations if they may already have been used). If the current MVP schema was never used with real data, replacing `0001` is acceptable; say so in the data-model doc.

### Model to design (map from domain)

Keep the current shape unless a rule below forces a change:

- **groups:** id, name, currency, access mode (`public_link` | `private`), created at. Creator: nullable or omitted so a link group can be created without an auth user (this is the main break from the current schema).
- **group_members:** person on the trip; name required; email optional (needed later for private invites).
- **group_member_identities:** links `auth.users` to a member in a group (at most one auth user per group; a member may have zero or one identity in the MVP).
- **expenses:** description, amount in minor units, payer member, timestamps. Optional display date can wait.
- **expense_shares:** one row per participating member; amounts in minor units; shares for an expense must sum to the expense total (enforce in the application in MVP; add a DB constraint or trigger later if we want).

Do **not** add a settlements table in this phase.

### Integrity rules

- Payer and share members must belong to the same group as the expense (the current composite FKs are good; keep them).
- Amounts: expense total `> 0`; share amounts `>= 0`.
- Unique email per group when email is present.
- Deleting a group deletes members and expenses. Do not delete a member who still pays or shares an expense (restrict), or define an explicit reassignment rule in the data-model doc.

### RLS

Document and implement:

- `ENABLE ROW LEVEL SECURITY` on every public table (already true).
- **No policies for `anon` / `authenticated` in the first version**, so the Supabase API cannot read or write app data even if the anon key leaks into the client later.
- The SvelteKit server uses the direct/pooler connection and bypasses RLS (Postgres owner/superuser or a table-owner role). State this explicitly so nobody “fixes” it by adding the anon key to the browser.
- Sketch the **future** policies for private groups (authenticated user may access rows for groups where they have a `group_member_identities` row) without enabling them until the browser or a restricted DB role needs them.
- Link-group access is **not** expressed as “anyone who knows the UUID can `SELECT` via PostgREST.” That would make the anon key a full public API. The server enforces the link.

### Migration process

1. Update `schema.ts`.
2. `npm run db:generate`.
3. Review the SQL (especially FKs to `auth.users` and RLS).
4. Apply on the development database with `npm run db:migrate`.
5. Commit schema + migration together.

**Done when:** `docs/data-model.md` explains tables, relationships, money, access, and RLS; the migration applies cleanly on a fresh development database.

---

## Phase 4 — Rough MVP of the core feature

**Goal:** A usable link-group flow. Ugly is acceptable; the split math and the URL-sharing loop are not.

**In scope**

- Home: create a link group (name, currency, first members).
- Group page at the secret URL:
  - list members; add a member by name
  - list expenses
  - add an expense: description, amount, payer, participants (all selected by default), optional custom amounts
  - even split among selected members, with the remainder rule from the domain doc
  - show each member’s net balance
  - show suggested repayments (minimize number of transfers)
- Copy-able group URL
- Basic empty and error states (invalid amount, shares not summing, group not found)
- shadcn-svelte for buttons, inputs, and dialogs as needed

**Out of scope for this MVP**

- Google sign-in UI
- Private groups and email invites
- Recording repayments
- Editing group currency after creation (can allow rename)
- Receipts, comments, categories, multi-currency
- PWA, accounts page, group directory
- Tests

**Suggested split of the work**

1. Pure functions: split amounts, net balances, minimized transfers.
2. Server actions: create group, add member, add expense (write shares in the same request).
3. Group page UI wired to those actions.
4. Manual pass through the travel story in [product-context.md](./product-context.md).

**Done when:** two people can share a URL, enter the plane / hotel / food example, and see who owes whom.

---

## After this plan

Not scheduled here, but the domain and architecture should not paint us into a corner:

- Google sign-in and linking an identity to a member
- Private groups and email invites
- Edit/delete polish and “I paid you back”
- Custom domain
- PWA
- Tests

## Open questions

Only reopen these if the working decisions are wrong:

- Should creating a **link** group require Google after all?
- Should phase 4 include private groups?
- Should suggested repayments be stored as first-class “settled” records in the first MVP?
