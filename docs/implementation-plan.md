# Implementation plan

This is the working plan for building Expenses Divider. Execute it in order. Product intent lives in [product-context.md](./product-context.md). Do not invent features that are not in that brief or in the working decisions below.

The existing repo is a rough MVP of stack and schema. Most of it will be reworked. Keep what still matches this plan; replace what does not.

## How to execute

Each phase produces artifacts. A phase is done when those artifacts exist and match the product context.

| Phase | Status | Goal | Artifacts |
| --- | --- | --- | --- |
| 1 | **Done** | Shared language for the product | [domain-overview.md](./domain-overview.md), [domain.md](./domain.md) |
| 2 | **Done** | Settled stack, architecture, local setup, deployment | [architecture.md](./architecture.md), [README.md](../README.md) |
| 3 | Not started | Data model, RLS, Drizzle schema, migration | `docs/data-model.md`, `src/lib/server/db/schema.ts`, a new Drizzle migration |
| 4 | Not started | Rough UI/server MVP of the core travel split | Working group create/view/add-expense/balances flow |

Later phases may rewrite earlier docs if a decision changes. Keep the docs the source of truth. Phases 1 and 2 are finished; later phases should follow the domain files and [architecture.md](./architecture.md).

## Working decisions

These resolve open points in the brief. Change them here if they are wrong; then continue.

1. **Public groups need no visible login.** Creating a public group, opening it, and adding expenses works with the URL. Under the hood the browser gets a Supabase **anonymous** session. “Who you are” is `group_member_identities`. The **creator is a member**, not an Auth user: anyone claiming that member (e.g. Bob) has full admin.
2. **Google sign-in is required for private groups.** There is never email/password. The app does not send mail: access is URL plus a Google account whose email is listed on the group.
3. **Phase 4 MVP is public groups only.** Private groups are specified in domain and architecture, but not built in the first UI.
4. **Members are named people.** A member can exist before anyone logs in. Google identity can later be linked to a member.
5. **One currency per group.** No currency conversion. For now every group is euro.
6. **Money is stored as integer minor units** (cents). Display uses the group currency.
7. **Settlement is computed, not recorded, in the MVP.** The app shows balances and a minimized list of suggested repayments. Marking a repayment as paid is out of the first MVP.
8. **Who can change what** follows [domain.md](./domain.md): in a public group, anyone acting as the creator member has admin (member list and all expenses); other members edit expenses they recorded; you may add your own name if you are not on the list.
9. **RLS applies on the request path.** SvelteKit loads and writes group data as the visitor’s Auth user (anonymous or Google), never as `service_role` or table owner. `DATABASE_URL` is for migrations only. The browser still does not query tables (performance). Policies are real, not a deny-all backstop. Details: [architecture.md](./architecture.md).
10. **PWA / native app and a custom domain are later.** Deploy the web app on Vercel first.
11. **No automated tests** until the owner asks for them. CI keeps typecheck, lint, and build.
12. **The product UI is German and English.** Default English when the visitor has no saved choice and the browser language is neither. Docs stay English.
13. **Performance matters, especially on phones.** Most use is on mobile, including older devices. Prefer server-rendered pages, little client JS, and no extra round trips. Details: [architecture.md](./architecture.md#performance). The UI is mobile first: [product-context.md](./product-context.md).

## Current repo (starting point)

Already in place and should be treated as the default unless phase 2 or 3 replaces it:

- SvelteKit, TypeScript, Tailwind CSS 4, shadcn-svelte (vega / neutral), Lucide
- `@sveltejs/adapter-vercel`
- Drizzle ORM + Drizzle Kit, `postgres` driver, transaction pooler (`prepare: false`)
- Tables: `groups`, `group_members`, `group_member_identities`, `expenses`, `expense_shares`
- RLS enabled on all app tables, with no client policies yet
- GitHub Actions: `ci` on pull requests and `main`; manual **Migrate production database** workflow
- Landing page copy only; no group UI yet

`created_by_user_id` on groups should not be the public-group creator. Phase 3 stores a **creator member** instead. RLS admin = identity linked to that member. Request-path code must not use the table-owner `DATABASE_URL`.

---

## Phase 1 — Document the domain

**Status: done.**

**Outputs:**

- [domain-overview.md](./domain-overview.md) — short walkthrough of the product in domain language
- [domain.md](./domain.md) — detailed terms and rules

These two files are the domain source of truth. Later phases should follow them. If they disagree with this plan’s working decisions or with [product-context.md](./product-context.md), update those documents to match the domain files.

---

## Phase 2 — Stack, architecture, environment, deployment

**Status: done.**

**Outputs:**

- [architecture.md](./architecture.md) — stack, request path, access, i18n, routes, env, CI/CD
- [README.md](../README.md) — clone-and-run

These two files are the architecture source of truth. Later phases should follow them (and the domain files). If they disagree with this plan, update the plan.

---

## Phase 3 — Data model, RLS, schema, migration

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
- Do not use `DATABASE_URL` / table owner / `service_role` for app queries. Phase 4 uses the user JWT.
- Private-group rules (email matches member) belong in the same policies even if that UI is later.

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

- Should creating a **public** group require Google after all?
- Should phase 4 include private groups?
- Should suggested repayments be stored as first-class “settled” records in the first MVP?
