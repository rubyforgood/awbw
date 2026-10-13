# ADR-0006 — Portal access is managed manually for now; `users.inactive` is retired

- **Status:** Accepted
- **Date:** 2026-10-13

## Context

A user can sign in when Devise's gates pass (`User#active_for_authentication?`):
the account is confirmed, not **locked** (`users.locked_at`), and not **inactive**
(`users.inactive`). Lock and inactive overlap in meaning, and only Lock is offered
on the user form — `inactive` shows only under `?admin=` or when it's already set.

Nothing ends access on its own. We considered deriving it from a person's
relationships — lapsing anyone whose facilitator affiliations had all ended or whose
memberships were all cancelled (rubyforgood/awbw#2653). That was rejected: it
contradicted earlier agreements about what access depends on, and it read
membership status in a way the upcoming membership rework replaces.

## Decisions

### D1 — Admins manage access by hand, with Lock

Until membership-based access exists (D3), an admin ends a person's access with
**Lock** and restores it with **Unlock**. Lock is the single, deliberate,
per-account switch, and each change is audited (`auth.account_locked` /
`auth.account_unlocked`). This was agreed with staff as acceptable for now.

### D2 — Affiliations have no bearing on portal access

Neither job nor facilitator affiliations (ADR-0003 D1) grant or remove access.
An affiliation ending says the art program or role ended, not that the person
should lose their account.

### D3 — Membership will decide access, through ActionPolicy

The intended rule: a person who paid for a year of membership has access until
that paid term expires. It is deferred until the membership rework lands, and it
belongs in authorization (ActionPolicy), not in the Devise sign-in gate. Don't
build on the current `Membership` cancelled/uncancelled reading for access.

### D4 — `users.inactive` is retired gradually, not removed

`inactive` stays honored as a sign-in gate so nobody it currently blocks regains
access, but it is **legacy**:

- No new code reads or writes it; Lock (D1) covers deactivating an account.
- The user form keeps showing it only when already set (or under `?admin=`), so an
  admin can clear it; it is not offered for new deactivations.
- It is dropped in a later migration once no account carries `inactive: true`.
  Until then, don't fold it into Lock or backfill `locked_at` from it — a lock is a
  distinct, audited event, and rewriting old flags would fabricate that history.
