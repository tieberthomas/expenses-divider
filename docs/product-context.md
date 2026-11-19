# Product context

This file is the product brief for Expenses Divider. The [implementation plan](./implementation-plan.md) should follow it. When product intent and a later technical choice disagree, update this file first, then the plan.

## What it is

Expenses Divider is a web app for splitting travel costs with a small group of people. It is similar to Splitwise, with a simpler, more focused experience.

Typical story: friends go on a trip. One person pays for flights, another for the hotel, another for food. They want a shared place to record who paid for what, who the cost was for, and who still owes whom.

The product UI is German and English. Developer docs stay English.

## Who it is for (now)

People organizing a trip who want to share a list of expenses and end up with a clear settlement. It is not aiming to be a general household-finance product yet.

## How people use it

1. Someone opens the site and creates an **expenses group** (a trip).
2. They share the group URL. The URL contains the group’s UUID.
3. Anyone with that URL can add expenses they paid.
4. For each expense they say:
   - who paid
   - what it was
   - how much
   - who the expense was for
5. By default the expense is for the whole group and is split evenly.
6. They can leave people out of a specific expense.
7. They can also assign exact amounts (Bob paid 15€; Alice’s share is 10€, Sarah’s is 5€).
8. The group can see running balances and a simple “who should pay whom” result.

## Access

There are two kinds of groups:

- **Link groups.** Anyone who has the URL can view the group and add expenses. No account is required.
- **Private groups.** Only invited people can add expenses. Invitations go out by email.

Accounts:

- There is no email/password sign-up.
- When a login is required, people sign in with Google.
- Link groups must stay usable without signing in.

## Product principles

- Sharing a trip should be as easy as sharing a link.
- Participants are people on the trip, not necessarily people with accounts.
- Splitting should cover the common cases (everyone, a subset, custom amounts) without extra concepts.
- The settlement should answer “who owes who how much?” in as few payments as possible.
- Better UX than Splitwise for this travel case matters more than matching Splitwise feature-for-feature.
- People will use it mostly on phones, including older phones. It should feel fast there. Opening a group and adding an expense should feel immediate.
- The UI is mobile first. Desktop is a wider version of the same screens, not a separate design.

## Later, not now

- Progressive Web App or native app
- Custom domain (none yet; the app will start on a platform URL)
- Tests
- A full Splitwise-style product (non-travel groups, IOUs between two people, offline receipts OCR, and so on)

## Stack preferences (from the product owner)

- SvelteKit and TypeScript
- Supabase
- Drizzle
- A UI component library (shadcn-svelte is the current choice)
- No tests for now
- GitHub for the repository

These preferences are recorded in [architecture.md](./architecture.md). That file is the source of truth for stack and deployment, not this brief.
