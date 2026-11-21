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
| 5 | **Done** | MVP scope | [mvp-scope.md](./mvp-scope.md) |
| 6 | Not started | Build the MVP | Working app as defined in the MVP scope |

Later phases may rewrite earlier docs if a decision changes. Keep the docs the source of truth. Phases 1–4 are finished; later phases should follow the domain files, [architecture.md](./architecture.md), [product-context.md](./product-context.md), and [data-model.md](./data-model.md). After phase 5, build only what [mvp-scope.md](./mvp-scope.md) allows.

## Working decisions

These resolve open points in the brief. Change them here if they are wrong; then continue.

1. **Public groups need no visible login.** Creating a public group, opening it, and adding expenses works with the URL. Under the hood the browser gets a Supabase **anonymous** session. “Who you are” is `group_member_identities`. The **creator is a member**, not an Auth user: anyone claiming that member (e.g. Bob) has full admin.
2. **Google sign-in is required for private groups.** There is never email/password. The app does not send mail: access is URL plus a Google account whose email is listed on the group.
3. **The first MVP is public groups only.** See [mvp-scope.md](./mvp-scope.md). Private groups are specified in domain and architecture, but not built in the first UI.
4. **Members are named people.** A member can exist before anyone logs in. Google identity can later be linked to a member.
5. **One currency per group.** No currency conversion. For now every group is euro.
6. **Money is stored as integer minor units** (cents). Display uses the group currency.
7. **Settlement is computed, not recorded, in the MVP.** The app shows balances and a minimized list of suggested repayments. Marking a repayment as paid is out of the first MVP.
8. **Who can change what** follows [domain.md](./domain.md). The first UI is narrower: [mvp-scope.md](./mvp-scope.md) (add expenses only; creator may add members later, not rename or remove).
13. **No switch-name UI.** After someone says who they are, they act as that member for that anonymous session. A new browser or lost session is asked again; that is not a product feature.
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

**Status: done.**

**Outputs:**

- [mvp-scope.md](./mvp-scope.md) — in-scope / out-of-scope for the first shippable slice

Phase 6 should follow that file. If it disagrees with this plan, update the plan.

---

## Phase 6 — Build the MVP

**Goal:** Implement exactly [mvp-scope.md](./mvp-scope.md). The first UI can look rough. Split amounts, balances, and the settlement suggestion must be correct. Creating a group, sharing the URL, and using that group together must actually work.

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

Answered in [mvp-scope.md](./mvp-scope.md): public only; repayments not stored; add-only expenses; no identity switch.
