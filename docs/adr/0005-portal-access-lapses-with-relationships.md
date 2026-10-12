# ADR-0005 — Portal access lapses with a person's relationships; `users.inactive` is retired

- **Status:** Accepted
- **Date:** 2026-10-12
- **Builds on:** [ADR-0003](0003-affiliations-as-the-record-of-two-relationships.md)
  (the facilitator affiliation as the record of an art program)

## Context

Until now a user lost portal access only when an admin acted on the account:
**Lock** (`users.locked_at`) or the older **inactive** flag (`users.inactive`). Both
are Devise gates (`User#active_for_authentication?`), they overlap in meaning, and
only Lock is shown on the user form — `inactive` appears only under `?admin=` or
when it's already set.

Nothing tied access to *why* someone has an account. A facilitator whose program
ended, or a member who cancelled, kept signing in until an admin remembered to
lock them. The two relationships that actually justify portal access are already
recorded: a **membership** (`Membership`, one uncancelled per person) and a
**facilitator affiliation** (ADR-0003 D1).

## Decisions

### D1 — Three gates, checked in order

A user can sign in only when all of these hold (`User#active_for_authentication?`,
mirrored by `User#has_access?` and the `User.has_access` scope):

1. **Not `inactive`** — the legacy flag (D4).
2. **Not locked** — `locked_at` is nil. Lock is the admin's deliberate,
   per-account switch (manual, or Devise's 10-failed-attempts lock).
3. **Access hasn't lapsed** — `PortalAccess#lapsed?` (D2).

Confirmation (`confirmed_at`) is still required by Devise underneath all three.

### D2 — Lapsed = had a qualifying relationship, has none current

A person is **lapsed** when they *have* a membership or a facilitator affiliation
but *none* of them is current:

- A membership is current when it isn't cancelled (`Membership.not_cancelled`, the
  same reading as `Person.membership_active`).
- A facilitator affiliation is current when it is **Active or Upcoming**
  (`Affiliation.with_status(ACTIVE_OR_UPCOMING)`). Upcoming counts so that minting
  a facilitator affiliation for a future training never *removes* access the
  person had a moment earlier with no affiliation at all.

Either current relationship is enough: a cancelled member who still facilitates,
or a lapsed facilitator who is a paying member, keeps access. Someone with **neither
kind of relationship on record is not gated** — staff, partners, and accounts
created before these records existed keep signing in as before. Job affiliations
(ADR-0003 D1) don't count either way.

### D3 — Admins and person-less accounts are never lapsed

A super-user (`super_user?`) is exempt: staff often carry an old facilitator
affiliation, and the rule must never lock out the people who would fix it. A user
with no linked `Person` has no relationships to read and is not gated.

### D4 — `users.inactive` is retired gradually, not removed

`inactive` stays honored as a gate (D1) so nobody it currently blocks regains
access, but it is **legacy**:

- No new code reads or writes it — lapsing (D2) covers the "they've moved on" case
  it was used for, and Lock covers the deliberate, per-account case.
- The user form keeps showing it only when already set (or under `?admin=`), so an
  admin can clear it; it is not offered for new deactivations.
- It is dropped in a later migration once no account carries `inactive: true`.
  Until then, don't fold it into Lock or backfill `locked_at` from it — a lapse or
  lock is a different, auditable event (`auth.account_locked`), and rewriting old
  flags would fabricate that history.

### D5 — Membership is only read where memberships are live

The membership leg of D2 applies only when `Membership.enabled?` (not yet in
production). Until memberships launch, production gating rests on facilitator
affiliations alone, so stray membership rows can't lapse anyone early.

### D6 — The rule is derived at read time, not stored

Lapsing is computed from the current memberships and affiliations on every check —
there is no `lapsed` column or nightly job. Ending an affiliation or cancelling a
membership takes effect on the person's next request; restoring one restores
access with no admin step. `PortalAccess.lapsed_person_ids` is the SQL twin of
`PortalAccess#lapsed?`, kept in lock-step by an agreement spec, so the "Has access"
filters and the sign-in gate can't disagree.
