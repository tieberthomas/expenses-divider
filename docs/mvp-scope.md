# MVP scope

What the first shippable slice includes and what it does not. Phase 6 builds only this. Domain, product context, architecture, and data model still win on meaning and rules; this file wins on **how much** of that is in the first UI.

**Done when:** two people can create a public group, share the URL, enter the Portugal story in [domain.md](./domain.md) (flights, hotel, dinner with Bob left out, lunch with two payers), and see balances plus a settlement suggestion.

The first UI can look rough. Split amounts, balances, and the settlement suggestion must be correct. Creating a group, sharing the URL, and using that group together must actually work.

---

## In this slice

**Public groups only.** No private-group UI, no Google sign-in UI. Anonymous Auth under the hood (no login screen). Euro only; the creator does not pick a currency.

### Home (`/`)

Create a public group:

- Group name
- Creator’s name (they become the creator member)
- Other members they already know (at least the rest of the trip they want listed now)
- Store that this browser acts as the creator member (identity + grant) in the same request
- After create: go to `/g/[groupId]` already acting as the creator. Do not ask who they are again on this session

### Group (`/g/[groupId]`)

- **Secret URL** that can be copied and shared
- **Say who you are** only if this browser has no identity on the group yet (everyone except the creator on the session that created it): pick an existing name, or add **your own** name (Lucas). Then act as that member on return visits (same anonymous session). No switch-name UI
- **Members** listed. Anyone acting as the creator member can **add** more names later. No rename or remove in this slice
- **Expenses** listed (description if present, total, who paid, cost shares, who recorded it)
- **Add expense** after saying who you are:
  - Description (optional)
  - Total (ordinary euro amount, stored as cents)
  - One or more **payments** (who paid, how much; must sum to the total)
  - **Even** split (default): every current member, or a **subset** by leaving people out; leftover cents follow [domain.md](./domain.md)
  - **Custom** cost shares (typed amounts; must sum to the total; zero means not on the expense)
- **Balances** for every member (paid minus cost shares)
- **Settlement suggestion** (who should pay whom). Not stored; not marked paid
- Empty states (no expenses yet) and error states (unknown or invalid group id)

### Creator member (this slice)

Anyone acting as the creator member can add expenses like anyone else. They can **add members** on the group page. They cannot rename or remove members in this slice. Others cannot change the member list except adding **their own** name when they say who they are.

### Languages and devices

German and English (default English). Locale cookie / `Accept-Language` as in [architecture.md](./architecture.md). **Mobile first**; usable on a phone without an app install. Server-rendered pages and form actions.

---

## Out of this slice

- Google sign-in UI and linking Google to a member
- Private groups, member emails, invite-by-email
- Choosing a currency; any currency other than euro; FX
- Recording that a repayment happened (“I paid you back”)
- Changing which member you act as after you already picked (not a product feature; a new browser or lost session is asked again)
- Editing or deleting an expense after save (add-only; balances update only when new expenses are added)
- Renaming or removing members
- Editing the group name after create
- Showing last editor (`updated_by` / `updated_at`) as its own UI
- A list of all groups, accounts, or “my trips”
- PWA / native app / custom domain
- Email
- Automated tests
- Schema or RLS changes unless this slice cannot be built without them

The data model already allows private groups, Google, expense updates, and last editor. This slice simply does not ship UI for them.

---

## Routes

Same as [architecture.md](./architecture.md): `/` create; `/g/[groupId]` the group. No other product routes.

---

## Manual check (phase 6)

Walk the Portugal story in [domain.md](./domain.md) on a phone-sized viewport, once in English and once in German: create, copy link, second browser says who they are, add the four expenses, read balances and suggested repayments. Confirm a stranger with the URL can open the group and a made-up id cannot.
