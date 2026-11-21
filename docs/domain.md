# Domain

This is the shared language for Expenses Divider. It is written for people, not for databases or frameworks. This file says what the words mean and which rules always hold.

When the data model or the app disagrees with this document, this document wins until it is deliberately changed.

---

## Expenses group

An **expenses group** (also a **group** or a **trip**) is the shared notebook for one journey.

A group has:

- a **name** people recognize (for example “Portugal 2026”)
- a **currency** (see [Money](#money))
- a **creator** (the person who started it)
- a list of **members**
- a list of **expenses**
- an **access mode**: either a public group or a private group

Creating a group is how the trip starts in the app. There is no global list of other people’s groups.

### Public group

A **public group** is meant to be shared like a document. Anyone who has the **group URL** can open it without an account. Treat the URL as a secret.

Who can do what after they open it is described under [People](#people).

### Private group

A **private group** is only for people the creator has listed with an email. Having the URL is not enough.

Private groups exist in the product language from the start. The first version of the app only needs to behave well for public groups.

### Group URL

The **group URL** (the **secret link**) is the address of one group. Sharing it is how a public group is shared. Losing it means losing easy access, the same way losing a shared document link does.

---

## People

### Creator

The **creator** is a **member**: the named person who started the group (for example Bob).

When they create the group, they list the people on the trip, including that creator name and the others they already know about (Bob, Alice, Linda). Creating the group already records that this browser is that creator member. They are not asked who they are when they land on the group.

In a **public group**, anyone acting as that member has the creator’s powers. If Bob created the group, anyone who says they are Bob can manage the group. That is not an account. Two people who both say they are Bob both have those powers.

In a **private group**, the creator still signs in with Google. They are still a member; their Google email is how they are that member.

Only someone with creator powers can remove or add people to the expenses group or change their name.

Other people cannot do those things. In a public group, the one exception is: if you open the link and you are not on the list yet, you may add **your own** name when you say who you are.

Someone with creator powers can also add, change, and delete **any expense** in the group, including expenses recorded by other members.

### Member

A **member** is a named person on the trip: Alice, Bob, Linda. The group tracks money between members, not between email addresses or Google accounts.

A member can exist before that person has ever opened the app. The creator can add “Linda” so her flights can be recorded even if Linda has not opened the link yet.

In a group, each member has a **name**. Names should be distinct enough that the group can tell people apart. Two members should not have the same name in the same group.

A person can be a member of many groups. Those groups do not share balances.

A new member does not automatically get a cost share of expenses already saved. They only join expenses from that point on.

A member who still has a payment or a cost share on any expense cannot be removed until those expenses are changed or deleted.

### Saying who you are

In a **public group**, the first time someone opens the group they are asked who they are, unless they just created it (they already act as the creator member). They see the names already on the trip (“Hey, are you Alice or Linda?”) and pick one.

They can also say they are someone new (“No, I’m Lucas”). That **adds a new member** with that name. They then act as that member.

After they have said who they are, they **act as** that member on this browser (the anonymous session). There is no switch to another name. A new browser or a lost session is asked again. Anyone acting as the same member is treated as the same person for recording and editing expenses. If two people both say they are Lucas, both can change expenses recorded as Lucas.

Saying who you are is not a login. It is a name on this trip.

### Signed-in person

A **signed-in person** is someone who has opened the app and signed in with Google. That is separate from being a member.

- In a **public group**, nobody has to sign in. People say who they are by picking or adding a name.
- In a **private group**, they must sign in with Google. If that Google account’s email is listed on the group, they get access as that member.

There is no email-and-password account. When a sign-in is needed, it is Google.

### Invite

In a **private group**, the creator lists each member with an **email**. That list is the invite. The app does not send mail. The creator shares the group URL themselves.

Someone gets access when all of this is true:

- they open that private group’s URL
- they are signed in with Google
- that Google account’s email is one of the emails on the group

They then act as the member who has that email. They do not have to accept anything.

If they open the URL signed in with an email that is not on the group, they do not get in.

Public groups do not use emails this way. Anyone with the URL can open a public group and say who they are.

---

## Money

Every group has one **currency**. All amounts in that group are in that currency. The app does not convert between currencies.

For now every group is in **euro**, and the person creating the group does not pick a currency. Later, they will choose the group’s currency when they create it. The currency does not change after that.

People enter and see ordinary amounts (15,00 €). Behind the scenes the group always works in the **smallest unit** of that currency (cents for euro). There are no fractions of a cent.

---

## Expenses

An **expense** is a cost the group wants to split, already paid by one or more people.

Examples: plane tickets, a hotel night, a restaurant bill.

An expense has:

- a **description** (what it was)
- a **total amount** (the whole bill), always greater than zero
- **payments** (which members paid, and how much each paid)
- **recorded by** (which member entered it; the member the person was acting as)
- **cost shares** (which members the expense was for, and how much of the total each of them is responsible for)

The people who pay and the people who have a cost share are members of the group. They do not have to be the same people: someone can pay without having a cost share, and someone can have a cost share without paying.

Often one person pays the whole amount. It can also be several people paying different parts of the same bill. Example: Bob, Lucas, Alice, and Linda have lunch for 75 €. Bob paid 50 €, Lucas paid 25 €. That is one expense, two payments. If it is split evenly among the four of them, Alice and Linda still each have a cost share of 18,75 € even though they paid nothing at the restaurant.

**Recorded by** is not the same as who paid. Lucas can enter an expense that Alice paid. That expense is still recorded by Lucas, so people acting as Lucas can change or remove it. The creator can change or remove it too.

Adding, changing, or removing an expense only affects that expense. It does not rewrite older ones.

### Payment

A **payment** is one member’s part of what was paid: “Bob paid 50 € of this lunch.”

A member with no payment did not pay any of this expense.

All payments of an expense must add up to the expense total. The whole bill is accounted for, and the payments cannot add up to more than the bill.

### Cost share

A **cost share** is one member’s part of one expense: “this expense is partly for Alice, and her part is 10 €.”

Only members with a cost share are “on” that expense. A member with no cost share is not responsible for any of it.

All cost shares of an expense must add up to the expense total. Nothing is left unassigned, and the cost shares cannot add up to more than the bill.

---

## How an expense is split

When someone adds an expense, they choose who paid (and how much each paid) and how the total is divided among cost shares.

### Even split (the default)

By default the expense is for **every current member** of the group, and the total is divided **evenly** among them.

“Current members” means the members who exist when the expense is saved. People added to the group later are not pulled into older expenses. People removed from an expense (see below) stay in the group; they are only left off that expense.

### Subset split

The person entering the expense can **leave members out**. Those people do not get a cost share of that expense. The total is then split evenly among the members who remain.

Leaving someone out applies only to that expense.

### Custom amounts

Instead of an even split, the person entering the expense can type each cost share (Alice’s cost share is 10 €, Sarah’s is 5 €).

Those amounts must add up to the total. Members with a custom amount of zero are not on the expense.

### Leftover cents

Some even splits do not come out exactly (10,00 € among three people). The leftover smallest units are given out one at a time so the cost shares still add up to the total.

Order: members who paid and also have a cost share, in the order they were added to the group, then the other members with a cost share in that same order.

Example: 10,00 € among Alice (who paid), Bob, and Sarah → Alice 3,34 €, Bob 3,33 €, Sarah 3,33 €.

---

## Balances and settling up

### Balance

A member’s **balance** is what they have paid minus what they are responsible for, across every expense in the group.

- A **positive** balance means the group owes them (they have paid more than their cost shares).
- A **negative** balance means they owe the group (their cost shares add up to more than they have paid).
- A **zero** balance means they are even.

Balances are a snapshot of the expenses as they stand. Change an expense, and the balances change with it.

### Settlement suggestion

A **settlement suggestion** is a short list of payments that would even everyone up: who should pay whom, and how much.

The app chooses a small number of payments rather than having every debtor pay every creditor. These are **suggestions**, not a record that money actually moved. Until the product has a way to mark a repayment as done, settling in real life does not change the group; deleting or adding expenses does.

---

## Access rules (summary)

| Action | Public group | Private group |
| --- | --- | --- |
| Open the group | Anyone with the URL | Signed in with Google, and that account’s email is listed on the group |
| Say who you are (pick a name, or add your own) | Anyone with the URL, first time they open it, except the creator on the session that created the group (already that member) | They are the member whose email matches the Google account |
| Rename or remove members, or add someone else | Anyone acting as the creator member | Only the creator |
| Add expenses | After saying who you are | After they have access as that member |
| Change or delete an expense | The member who recorded it, or anyone acting as the creator member | The member who recorded it, or the creator |
| Account required | No | Yes, Google |

There is no password account. Google is only required when the group is private, or later if a member wants to attach their Google account to their name.

---

## Typical story

Bob, Alice, and Linda go to Portugal. Bob creates a public group “Portugal 2026” and names Bob, Alice, and Linda. He sends Alice and Linda the URL.

Alice opens the link. She is asked whether she is Bob, Alice, or Linda. She picks Alice.

Lucas also got the link. He is asked the same question and says he is not on the list: he is Lucas. Lucas is added as a member.

- Alice records flights, 600 €, paid by Alice, split evenly. Recorded by Alice.
- Bob records the hotel, 300 €, paid by Bob, split evenly. Recorded by Bob.
- Linda records dinner, 15 €, paid by Linda; Alice’s cost share is 10 € and Linda’s is 5 €. Bob is left out. Recorded by Linda.
- Alice records lunch, 75 €. Bob paid 50 € and Lucas paid 25 €, split evenly among Bob, Lucas, Alice, and Linda. Recorded by Alice.

Alice can change the flights. She cannot change Bob’s hotel. Anyone who later says they are Alice can change the flights too.

The group now shows each person’s balance and a short suggestion of who should pay whom so they are even.
