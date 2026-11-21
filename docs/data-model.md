# Data model

Tables, constraints, and RLS for Expenses Divider.

---

## Tables

**groups** — one trip. `name`, `currency_code` (three letters, app writes `EUR`), `access_mode` (Postgres enum `group_access_mode`: `public` or `private`), `creator_member_id` (a member of this group), `created_at`.

Creating a group: insert the group (with the creator member’s id already chosen), insert members including that creator, then commit. The creator foreign key is **deferred** so that order is allowed.

**group_members** — a named person on the trip. Unique `lower(name)` per group. `email` optional; unique `lower(email)` per group when set (private groups). Cannot delete a member who still appears on a payment, cost share, or as `recorded_by` / `updated_by` on an expense.

**group_access_grants** — this Auth user may **see** this group. Inserted when they open a public URL (or when their Google email matches a member on a private group). Stops `SELECT` of every public group.

**group_member_identities** — this Auth user **acts as** this member in this group. One Auth user → one member per group. Several Auth users may be the same member (two browsers both Bob).

**expenses** — a bill: `description` (optional), `amount_cents` (> 0), `split_mode` (Postgres enum `expense_split_mode`: `even` or `custom`; not inferred from cents), `recorded_by_member_id` (who first entered it), `updated_by_member_id` (who last saved it), `created_at`, `updated_at`. On create, `updated_by` is the same as `recorded_by`. The app sets `updated_at` and `updated_by` on every save.

**payments** — who paid how much (`amount_cents` > 0). Several rows per expense.

**cost_shares** — who is responsible for how much (`amount_cents` >= 0). Several rows per expense.

Child rows carry `group_id` and use composite foreign keys so a member or expense cannot belong to another group. Deleting a group deletes its members, grants, identities, and expenses.

Auth user ids reference `auth.users` (defined in the migration SQL, not in Drizzle).

---

## RLS

Enabled on every table. Policies live on the Drizzle tables (`pgPolicy` in `schema.ts`). Helpers, table GRANTs, deferred creator FK, and `auth.users` FKs stay in SQL. Request path uses the visitor’s JWT (`anon` / `authenticated`). App queries do not use a table-owner connection.

Helpers (SECURITY DEFINER, so policies do not recurse): grant present, group is public, Google email matches a member, acting member id, is creator (identity on `creator_member_id`).

- **Read** group and its children: a grant for `auth.uid()`.
- **Insert group:** any signed-in user (anonymous counts). Then insert grant, members, identity in the same request.
- **Insert grant:** own `auth.uid()`, and the group is public **or** the JWT email matches a member.
- **Members:** insert if grant, creator, or the group still has no grants (bootstrap while creating). Change or delete members: creator only.
- **Identity:** insert/update own `auth.uid()` on a granted group.
- **Expenses:** insert with `recorded_by` and `updated_by` = acting member. Change or delete if acting member recorded it **or** is the creator member. On update, `updated_by` must be the acting member (`recorded_by` stays the original recorder). Payments and cost shares follow the parent expense.

No policy that is true for every public group.

---

## Create a public group (order)

1. Anonymous session (`auth.uid()`).
2. Choose a UUID for the creator member. Insert `groups` with that `creator_member_id`.
3. Insert own row in `group_access_grants`.
4. Insert members (including the creator).
5. Insert `group_member_identities` (this user → creator member).
6. Commit (deferred creator FK).
