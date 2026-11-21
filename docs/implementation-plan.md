# Implementation plan

This is the working plan for building Expenses Divider. Execute it in order. Do not invent features that are not in the domain, architecture, product context, and MVP scope (once those phases are done).

The existing repo is a rough MVP of stack and schema. Most of it will be reworked. Keep what still matches this plan; replace what does not.

## How to execute

Each phase produces artifacts. A phase is done when those artifacts exist and match the earlier source-of-truth docs.

| Phase | Status | Goal | Artifacts |
| --- | --- | --- | --- |
| 1 | **Done** | Shared language for the product | [domain-overview.md](./domain-overview.md), [domain.md](./domain.md) |
| 2 | **Done** | Settled stack, architecture, local setup, deployment | [architecture.md](./architecture.md), [README.md](../README.md) |
| 3 | **Done** | Product context (who it is for, UX, performance, languages, constraints) | [product-context.md](./product-context.md) |
| 4 | **Done** | Data model, RLS, Drizzle schema, migration | [data-model.md](./data-model.md), `src/lib/server/db/schema.ts`, `supabase/migrations/20261121120000_create_expenses_divider.sql` |
| 5 | Not started | MVP scope | `docs/mvp-scope.md` |
| 6 | Not started | Build the MVP | Working app as defined in the MVP scope |

Later phases may rewrite earlier docs if a decision changes. Keep the docs the source of truth. Phases 1–4 are finished; later phases should follow the domain files, [architecture.md](./architecture.md), [product-context.md](./product-context.md), and [data-model.md](./data-model.md). After phase 5, build only what the MVP scope allows.

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
9. **RLS applies on the request path.** SvelteKit loads and writes group data as the visitor’s Auth user (anonymous or Google), never as `service_role` or table owner. The browser still does not query tables (performance). Policies are real, not a deny-all backstop. Details: [architecture.md](./architecture.md).
10. **PWA / native app and a custom domain are later.** Deploy the web app on Vercel first.
11. **No automated tests** until the owner asks for them. CI keeps typecheck, lint, and build.
12. **Languages, performance, and mobile-first** live in [product-context.md](./product-context.md). Architecture keeps only the technical implications (server render, little JS).

## Current repo (starting point)

Already in place and should be treated as the default unless a later phase replaces it:

- SvelteKit, TypeScript, Tailwind CSS 4, shadcn-svelte (vega / neutral), Lucide
- `@sveltejs/adapter-vercel`
- Drizzle schema + Kit generate; apply with `supabase db push`
- Tables: see [data-model.md](./data-model.md)
- GitHub Actions: `ci` on pull requests and `main`
- Landing page copy only; no group UI yet

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

**Status: done.**

**Outputs:**

- [product-context.md](./product-context.md) — audience, typical use, devices, speed, languages, UX bar, what is not now

This file is the source of truth for product intent that is not domain language and not stack. Later phases should follow it. If it disagrees with this plan, update the plan.

---

## Phase 4 — Data model, RLS, schema, migration

**Status: done.**

**Outputs:**

- [data-model.md](./data-model.md) — tables, grants vs identities, RLS
- `src/lib/server/db/schema.ts`
- `drizzle/meta/` (Kit generate snapshots)
- `supabase/migrations/20261121120000_create_expenses_divider.sql` (applied via `supabase db push`)

Later phases should follow the data model. If they disagree with this plan, update the plan.

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
