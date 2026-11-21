# Implementation plan

This is the working plan for building Expenses Divider. Execute it in order. Do not invent features that are not in the domain, architecture, product context, and MVP scope (once those phases are done).

The existing repo is a rough MVP of stack and schema. Most of it will be reworked. Keep what still matches this plan; replace what does not.

## How to execute

Each phase produces artifacts. A phase is done when those artifacts exist and match the earlier source-of-truth docs.

| Phase | Status | Goal | Artifacts |
| --- | --- | --- | --- |
| 1 | **Done** | Shared language for the product | [domain-overview.md](./domain-overview.md), [domain.md](./domain.md) |
| 2 | **Done** | Settled stack, architecture, local setup, deployment | [architecture.md](./architecture.md), [README.md](../README.md) |
| 3 | Not started | Product context (who it is for, UX, performance, languages, constraints) | [product-context.md](./product-context.md) |
| 4 | Not started | Data model, RLS, Drizzle schema, migration | `docs/data-model.md`, `src/lib/server/db/schema.ts`, a new Drizzle migration |
| 5 | Not started | MVP scope | `docs/mvp-scope.md` |
| 6 | Not started | Build the MVP | Working app as defined in the MVP scope |

Later phases may rewrite earlier docs if a decision changes. Keep the docs the source of truth. Phases 1 and 2 are finished; later phases should follow the domain files and [architecture.md](./architecture.md). After phase 3, also follow product context. After phase 5, build only what the MVP scope allows.

## Working decisions

These resolve open points in the brief. Change them here if they are wrong; then continue.

1. **Public groups need no visible login.** Creating a public group, opening it, and adding expenses works with the URL. Under the hood the browser gets a Supabase **anonymous** session. “Who you are” is `group_member_identities`. The **creator is a member**, not an Auth user: anyone claiming that member (e.g. Bob) has full admin.
2. **Google sign-in is required for private groups.** There is never email/password. The app does not send mail: access is URL plus a Google account whose email is listed on the group.
3. **The first MVP is public groups only** (to confirm in the MVP scope phase). Private groups are specified in domain and architecture, but not built in the first UI.
4. **Members are named people.** A member can exist before anyone logs in. Google identity can later be linked to a member.
5. **One currency per group.** No currency conversion. For now every group is euro.
6. **Money is stored as integer minor units** (cents). Display uses the group currency.
7. **Settlement is computed, not recorded, in the MVP.** The app shows balances and a minimized list of suggested repayments. Marking a repayment as paid is out of the first MVP.
8. **Who can change what** follows [domain.md](./domain.md): in a public group, anyone acting as the creator member has admin (member list and all expenses); other members edit expenses they recorded; you may add your own name if you are not on the list.
9. **RLS applies on the request path.** SvelteKit loads and writes group data as the visitor’s Auth user (anonymous or Google), never as `service_role` or table owner. `DATABASE_URL` is for migrations only. The browser still does not query tables (performance). Policies are real, not a deny-all backstop. Details: [architecture.md](./architecture.md).
10. **PWA / native app and a custom domain are later.** Deploy the web app on Vercel first.
11. **No automated tests** until the owner asks for them. CI keeps typecheck, lint, and build.
12. **Languages, performance, and mobile-first** are product-context concerns (phase 3), not domain terms. Draft notes: UI is German and English (default English); the app must feel fast on older phones; UI is mobile first. Phase 3 writes these into [product-context.md](./product-context.md). Architecture may keep the technical implications (server render, little JS).

## Current repo (starting point)

Already in place and should be treated as the default unless a later phase replaces it:

- SvelteKit, TypeScript, Tailwind CSS 4, shadcn-svelte (vega / neutral), Lucide
- `@sveltejs/adapter-vercel`
- Drizzle ORM + Drizzle Kit, `postgres` driver, transaction pooler (`prepare: false`)
- Tables: `groups`, `group_members`, `group_member_identities`, `expenses`, `expense_shares`
- RLS enabled on all app tables, with no client policies yet
- GitHub Actions: `ci` on pull requests and `main`; manual **Migrate production database** workflow
- Landing page copy only; no group UI yet

`created_by_user_id` on groups should not be the public-group creator. Phase 4 (data model) stores a **creator member** instead. RLS admin = identity linked to that member. Request-path code must not use the table-owner `DATABASE_URL`.

---

## Phase 1 — Document the domain

**Status: done.**

**Outputs:**

- [domain-overview.md](./domain-overview.md) — short walkthrough of the product in domain language
- [domain.md](./domain.md) — detailed terms and rules

These two files are the domain source of truth. Later phases should follow them. If they disagree with this plan’s working decisions, update the plan to match the domain files.

---

## Phase 2 — Stack, architecture, environment, deployment

**Status: done.**

**Outputs:**

- [architecture.md](./architecture.md) — stack, request path, access, i18n, routes, env, CI/CD
- [README.md](../README.md) — clone-and-run

These two files are the architecture source of truth. Later phases should follow them (and the domain files). If they disagree with this plan, update the plan.

---

## Phase 3 — Product context

**Status: not started.** A draft [product-context.md](./product-context.md) already exists from earlier in the project. This phase rewrites it so it is the source of truth for product intent that is **not** domain language and **not** stack/architecture.

**Write:** [product-context.md](./product-context.md)

**Put here (not in domain.md, not as a UI chapter in architecture.md):**

- Who the product is for, and who it is not for
- Typical use (travel split, share a URL)
- Languages (German and English UI; docs in English; default English)
- Performance: the app must feel fast, including on older phones and slow connections
- Mobile first: designed for phones; desktop is the same screens, wider
- UX bar (simpler than Splitwise for this case)
- Constraints that are product, not domain: no tests for now, no PWA yet, no custom domain yet, no email from the app

Align the draft with the domain (public vs private groups, no mail invites, creator is a member). Drop stale “link group” / “invitations go out by email” wording. Drop stack lists; those live in architecture.

**Done when:** a new reader can answer “what are we building, for whom, on which devices, with which quality bar?” from this file alone, without opening architecture.md.

---

## Phase 4 — Data model, RLS, schema, migration

**Goal:** A model that matches the domain, including RLS. Implement it in Drizzle and ship a migration. Document it.

**Write:** `docs/data-model.md`  
**Change:** `src/lib/server/db/schema.ts`  
**Generate:** a new Drizzle migration (do not hand-edit old applied migrations if they may already have been used). If the current MVP schema was never used with real data, replacing `0001` is acceptable; say so in the data-model doc.

### Model to design (map from domain)

Keep the current shape unless a rule below forces a change:

- **groups:** id, name, currency, access mode (`public_link` | `private`), created at. Creator: a **member** (`creator_member_id` or equivalent), not an Auth user. Anyone linked to that member has admin in a public group.
- **group_members:** person on the trip; name required; email optional (needed later for private invites).
- **group_member_identities:** links `auth.users` to a member in a group (one Auth user maps to one member per group; several Auth users may be the same member, e.g. two people claiming Lucas).
- **group access grants** (name in the data-model doc): this `auth.uid()` may see this group. Inserted when they open a public group URL, so RLS does not allow listing every public group.
- **expenses:** description, amount in minor units, payer member, timestamps. Optional display date can wait.
- **expense_shares:** one row per participating member; amounts in minor units; shares for an expense must sum to the expense total (enforce in the application in MVP; add a DB constraint or trigger later if we want).

Do **not** add a settlements table in this phase.

### Integrity rules

- Payer and share members must belong to the same group as the expense (the current composite FKs are good; keep them).
- Amounts: expense total `> 0`; share amounts `>= 0`.
- Unique email per group when email is present.
- Deleting a group deletes members and expenses. Do not delete a member who still pays or shares an expense (restrict), or define an explicit reassignment rule in the data-model doc.

### RLS

Document and implement (must match [architecture.md](./architecture.md); do not bypass):

- `ENABLE ROW LEVEL SECURITY` on every public table (already true).
- **Policies for `anon` and `authenticated`** so `auth.uid()` can read/write only what the domain allows (grants, identities, recorded-by, creator **member**).
- No `USING (true)` that would let the anon key list every group.
- Do not use `DATABASE_URL` / table owner / `service_role` for app queries. Later app code uses the user JWT.
- Private-group rules (email matches member) belong in the same policies even if that UI is later.

### Migration process

1. Update `schema.ts`.
2. `npm run db:generate`.
3. Review the SQL (especially FKs to `auth.users` and RLS).
4. Apply on the development database with `npm run db:migrate`.
5. Commit schema + migration together.

**Done when:** `docs/data-model.md` explains tables, relationships, money, access, and RLS; the migration applies cleanly on a fresh development database.

---

## Phase 5 — MVP scope

**Status: not started.**

**Write:** `docs/mvp-scope.md`

After the data model exists, decide **what the first shippable slice includes** and what it does not. This is not the implementation. It is the contract for phase 6.

Settle at least:

- Public groups only vs any private-group UI
- Create group, say who you are, add expenses (payments + cost shares), balances, settlement suggestion
- What the creator member can do in this slice
- Languages and mobile-first as they apply to this slice
- Explicit out of scope (Google UI, recording repayments, PWA, tests, …)

A starting draft to confirm or cut, not to treat as already decided:

- Home: create a public group (name, members; euro)
- Group page at `/g/[groupId]`: members, expenses, add expense (even split or custom amounts, one or more payments), balances, suggested repayments
- Copy-able group URL; empty and error states
- Out of scope: Google sign-in UI, private groups, marking repayments paid, extra currencies, PWA, tests

**Done when:** `docs/mvp-scope.md` lists in-scope and out-of-scope so phase 6 does not invent features.

---

## Phase 6 — Build the MVP

**Goal:** Implement exactly [mvp-scope.md](./mvp-scope.md). Ugly is acceptable; the split math and the URL-sharing loop are not.

**Suggested split of the work**

1. Pure functions: split amounts, net balances, minimized transfers.
2. Server actions: create group, add member, add expense (write payments and cost shares in the same request).
3. Group page UI wired to those actions (mobile first).
4. Manual pass through the travel story in [product-context.md](./product-context.md).

**Done when:** the MVP scope’s “done when” is met (by default: two people can share a URL, enter the plane / hotel / food example, and see who owes whom).

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

- Should creating a **public** group require Google after all?
- Should the first MVP include private groups?
- Should suggested repayments be stored as first-class “settled” records in the first MVP?
