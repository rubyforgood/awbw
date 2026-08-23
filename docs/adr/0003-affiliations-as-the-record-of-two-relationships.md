# ADR-0003 — Affiliations record two relationships, and only one of them is the art program

- **Status:** Accepted
- **Date:** 2026-08-19
- **Extends:** [ADR-0001](0001-organization-affiliation-and-program-status.md) (supersedes its
  "Active affiliation" vocabulary entry — see D2 below)

## Context

ADR-0001 pinned how program status is computed. It left two things implicit that
have since caused real bugs:

1. **`affiliations` carries two different relationships in one table**, and only
   one of them says anything about the art program. Code that reads "the person's
   affiliations with this org" without saying which kind it means has been wrong
   more than once.
2. **Two different questions get asked of the same rows** — "what was true on
   date X" and "what is true now" — and they need different inputs. ADR-0001
   described `inactive` as a cache of the dates, which made the two look
   interchangeable. They aren't, and reconciliation broke the distinction: ending
   a no-show's affiliation retroactively changed an organization's program status
   at trainings years earlier.

This ADR names the two relationships, splits the two questions, and writes down
what has to be true for the annual grant figures to be trustworthy.

## Decisions

### D1 — One table, two relationships

An `Affiliation` is a Person ↔ Organization link. Its `title` decides which of two
relationships it records, and they are not interchangeable:

- **Job affiliation** — the role the person holds at the org ("Counselor",
  "Program Director", "Lead Facilitator"). It answers *who this person is to this
  organization*. It carries **no** start date by default: we rarely know when they
  took the job, and dating it to a registration would misrepresent that.
- **Facilitator affiliation** — `title` exactly `"Facilitator"` (trimmed,
  case-sensitive; see `Affiliation#facilitator?` and the `.facilitators` scope). It
  answers *this organization was running an art program, staffed by this person,
  over this period.* It is dated to the training that conferred it (ADR-0001 D8).

**Only the facilitator affiliation feeds program status.** A job affiliation never
makes an org active, never makes it Ongoing, and is never touched by
reconciliation. One person can hold both at the same org at the same time, and
normally does — a "Lead Facilitator" job affiliation plus a standing "Facilitator"
one (`AffiliationServices::CreateFromRegistration`).

**Being a facilitator is conferred by a training, not by attending an event.** Only
a `facilitator_training` registration mints a facilitator affiliation; other
org-linked registrations mint the job affiliation alone.

### D2 — `inactive` is an override, not a cache

ADR-0001 called `inactive` "a cached column derived from the dates on save," so
that "active" reduced to the dates. **That is no longer true.** `inactive` is now
an independent flag that can end an affiliation the dates still read as current:

- It is still **derived** from the dates when no one says otherwise
  (`set_inactive_from_dates`).
- An **explicit** assignment wins — `Affiliation#inactive_supplied` marks that a
  caller supplied the value deliberately, so a later edit to an unrelated date
  can't quietly undo it.

Why it has to exist: a one-day training that starts and ends today produces an
affiliation whose end date is today, and `end_date >= today` reads as active. Without
the flag a no-show would keep facilitator status for the rest of the day. The
standalone affiliation editor exposes the same flag so an admin can end a row
effective now without inventing a false end date.

### D2a — Provenance is `event_registration_id`, and there is no `event_id`

An affiliation links to the **registration** that minted it
(`affiliations.event_registration_id`, nullable, `on_delete: :nullify`). There is
deliberately **no `event_id`** — the event is reachable only through the
registration.

What the FK does and does not mean:

- **It is the auto-vs-manual gate.** `NULL` means hand-entered or historical;
  present means the registration flow created this row. `ReconcilePerson`'s
  `include_unowned:` switches on exactly this, and D6's "the row this training
  minted" is `affiliation.event_registration&.event_id == event.id`.
- **It is NOT the completion signal.** Creation dedupes, so one affiliation can be
  backed by several training registrations while the FK records only the *creating*
  one. Reading completion off `affiliation.event_registration.attended?` would end a
  returning facilitator whose first training was a no-show but who attended a later
  one. Completion is a query across **all** of the person's facilitator-training
  registrations for that org (`ReconcilePerson#completed_training?`).
- **It is scoped to the current org.** Repointing an affiliation at a different
  organization nulls it (`reset_org_scoped_links_on_org_change`), because the minting
  registration no longer applies. Invariant: **FK present ⟺ this row was auto-minted
  for its current organization.**
- **It says nothing about the kind of relationship.** Both kinds of row (D1) carry
  it — a job affiliation minted by a non-training registration has a registration
  whose event is not a facilitator training. `event_registration.event.facilitator_training?`
  must be checked, never assumed.

Two consequences worth knowing:

- **Provenance is lossy by design.** `EventRegistration has_many :affiliations,
  dependent: :nullify` and the FK is `on_delete: :nullify`, so deleting a
  registration leaves its affiliations standing with a `NULL` link. An auto-minted
  row silently becomes indistinguishable from a hand-entered one, and the default
  `include_unowned: false` gate will then spare it. That is the safe direction to
  fail, but it means the gate is a floor, not a guarantee.
- **The reverse lookup is cheap.** `index_affiliations_on_event_registration_id`
  means "which affiliations did this registration mint" is an indexed read, which is
  what lets the affiliation edit page show its minting event inline
  (`Analytics::AffiliationTimeline`).

### D3 — Two questions, two inputs

| Question | Anchored on | Reads |
|---|---|---|
| **Historical** — "what was true on date X" | an explicit date | **dates only** |
| **Current** — "what is true now" | now | **dates *and* the `inactive` flag** |

- Historical: `FacilitatorProgramStatus` (New / Ongoing / Reinstated) and the
  `Affiliation.active_by_date_on(date)` scope. They deliberately ignore `inactive`,
  because the flag describes *now* and a historical answer must not move when
  someone's status changes later.
- Current: `Affiliation#active?`, the `.active` / `.active_or_pending` scopes, and
  `OrganizationDecorator#organization_status_bucket`.

**The corollary that cost us a bug:** because historical readers ignore the flag,
they can only be kept honest by writing **truthful dates**. See D6.

### D4 — The organization's current status: Active / Formerly active / Never active

Derived purely from facilitator affiliations
(`OrganizationDecorator#organization_status_bucket`, ADR-0001 D3):

- any **active** facilitator affiliation → **Active**
- facilitator affiliation(s) but **all ended** → **Formerly active**
- **no** facilitator affiliation → **Never active**

**Formerly active is a subset of "not active."** The index filter treats it that
way (`Organization.program_status(:formerly_or_never)`), and any UI offering an
active/inactive choice must fold Formerly active and Never active under inactive
while still showing them apart — "used to run a program" and "never ran one" are
different facts about an org and only one of them is a lapse worth chasing.

The in-memory bucket and the SQL scope must agree; they are two spellings of one
rule and are tested against each other.

**The stored `organization_status` column is not an independent input.** It is
maintained *from* the affiliations (`sync_organization_status_with_affiliations`)
and is not consulted when computing the bucket (ADR-0001 D3/D3a). An org is active
because someone is facilitating there, not because a column says so.

### D5 — The anchor date, and what it's for

Program status is one value per **(organization, anchor date)**. In event context
the anchor is the event's `start_date`; with no event in view it falls back to
January 1 of the current year (ADR-0001 D7).

These figures back grant applications, so the property that matters is
**stability**: asking the same question about the same past date must give the same
answer forever, no matter what has happened to the people involved since. Two
consequences:

- Any anchor is legitimate, not just event dates. Comparing **Jan 1 vs Dec 31** of
  a year is a supported use — it's how "what moved this year" gets answered.
- Any write that changes an affiliation's dates is a write to the historical
  record. It must be justified against D6.

### D6 — Delete what the training assumed; only end what actually happened

When someone doesn't complete a training, what reconciliation does to their
facilitator affiliation depends on what that row represents:

- **The row this training minted** (owned by an `event_registration` for this
  event) — **deleted**. It recorded an *assumption* that the person would become a
  facilitator on the training date. They didn't, so there is no period to preserve
  and nothing is lost by removing it. It never counted as prior history anyway
  (ADR-0001 D5/D8 use a strict `<`), so no anchored verdict moves.
- **Any older row** — hand-entered, or minted by an earlier training — **ended** on
  this training's start date, never deleted. It records facilitation that really
  happened. Deleting it, or dating it back to its own start, would erase years of
  history and retroactively flip the org from Ongoing to Reinstated at every
  training in between.

An end date is never written before the row's own start date; a row starting after
this training same-days instead.

**Deleting the minted row is what lets reconciliation stop relying on the `inactive`
flag.** A same-dayed row could land on today and still read as active by dates
alone, which is why D2's flag existed here. A deleted row has no such problem, and
an older row is ended on a training date that has already passed, so the date rule
derives `inactive` by itself. The flag is still set on the older row for the one
case that remains — reconciling on the day the training ends.

**What a deletion costs:** the row's comments go with it, so the "why" D6b records
survives only for ended rows. The deletion itself is still on the record as a
`destroy.affiliation` Ahoy event carrying the full attribute snapshot.

The org's *current* bucket is expected to change — that's the point. Its *anchored*
verdicts are not.

### D6a — A return after a lapse is a new row, never a reopened one

When someone whose facilitator affiliation has ended completes a training for that
organization again, reconciliation **creates a second affiliation** dated to the new
training. It does not clear the old row's end date.

Reopening it would swallow the gap: `Jan 2023 – Jan 2024, Aug 2026` collapses to
`Jan 2023`, and the organization retroactively reads Ongoing across years it was not
running a program. The lapse is the fact the two rows exist to record — ADR-0001 D2
renders exactly that shape, and `CreateFromRegistration` has always minted a second
row rather than extending an ended one (an ended facilitator affiliation does not
block a new one).

So there is no `:reactivate` action. An ended row is left alone with the reason
"Ended — a return is recorded as a new affiliation", and the return shows up as an
ordinary `:create`. The rule for proposing that create: the person has **no active**
facilitator affiliation for the org, and either never had one or has completed a
training here.

This is the mirror of D6. D6 stops an ending from reaching too far back; D6a stops a
reactivation from reaching too far forward. Both exist because the historical readers
(D3) trust the dates.

### D7 — What has to be tested

The arithmetic is what the grant figures rest on, so it is covered directly rather
than inferred from the single-affiliation cases
(`spec/services/facilitator_program_status_math_spec.rb`):

1. **Several people at one anchor** — one person still facilitating keeps the org
   Ongoing however many others have left; Reinstated requires *every* earlier
   person to have ended; people arriving *at* the training don't rescue a lapsed
   program; non-facilitator titles never count.
2. **One organization at several anchors** — Jan 1 vs Dec 31 of the same year in
   both directions (a program starting mid-year, a program lapsing mid-year), and
   a full new → ongoing → reinstated → ongoing walk across a lapse and a return.
3. **Stability** — a past anchor keeps its verdict after the program later ends.
4. **Both questions on the same org** — Ongoing at a past training while Formerly
   active today, and vice versa.
5. **The bucket agrees with the SQL scope** the index filter uses.
6. **Reconciliation doesn't move an anchored verdict** — D6, both branches: the
   minted row is deleted, the older row ended at the training date.
7. **A return after a lapse adds a row and leaves the lapse intact** — D6a, asserted
   on both the row count and the mid-gap verdict.

Adding a rule here means adding a case there.

## Notes / open items

- **`inactive_reason` is not yet modelled.** Nothing records *why* an affiliation
  ended — an admin's manual end date, a reconciliation after a no-show, or a
  derivation from the dates. Worth adding as a plain string column constrained by a
  constant if the distinction ever needs to be surfaced or filtered; deliberately
  deferred until there's a reader for it.
- **The public reader says "by date".** `Affiliation.active_by_date_on(date)` names
  the input that separates it from the current-state `active?` / `.active`, and asks
  whether **one affiliation's own period** covered that date. The organization-level
  questions are built on top (D4 for now, `FacilitatorProgramStatus` for a date).
  Anything new answering "as of a date" should follow the same convention.
  `FacilitatorProgramStatus` keeps its own `active_on_anchor` — it is private to a
  file upstream edits often, and renaming it there bought a recurring rebase
  conflict for no call-site clarity.
- **ADR-0001's vocabulary entry for "Active affiliation" is superseded by D2**, and
  its note that an affiliation is "not tied to any event" is superseded by D2a — it
  is tied to a *registration*, which is not the same thing.
