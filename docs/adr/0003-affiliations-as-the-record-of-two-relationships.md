# ADR-0003 — Affiliations record two relationships, and only one of them is the art program

- **Status:** Accepted
- **Date:** 2026-08-19
- **Revised:** 2026-08-24 — D6a reversed in part (reconciliation reopens an ending it
  applied for the same training, instead of always adding a second row)
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
- **Any older row** — hand-entered, or minted by an earlier training — **ended**,
  never deleted. It records facilitation that really happened. Deleting it, or
  dating it back to its own start, would erase years of history and retroactively
  change the org's status at every training in between.
- **The row this training minted, when the person attended *part* of it**
  (`incomplete_attendance`) — **ended**, not deleted. Provenance is not the whole
  test: the question is whether anything happened. A no-show or a cancellation means
  the assumption never came true and there is nothing to keep; a partial attendance
  means they were here, so the row and its comments stay **on the record**. It
  same-days (the end date can't precede its own start).

  **Kept on the record is not the same as counted.** This bullet originally read that
  same-day row as "a facilitator term that was brief"; it is not one.
  [ADR-0001](0001-organization-affiliation-and-program-status.md) **D8a** drops every
  zero-length row from every organization-level figure, and **only an attended training
  confers facilitation** — so a partial attendance leaves an auditable row that counts
  toward nothing. Two consequences to know: the bulk reconcile page **disables
  Deactivate for a row this training minted** and preselects Delete, so in practice
  these rows are usually deleted by an admin rather than same-dayed; and the org still
  appears normally *at that training* either way, because `incomplete_attendance` is an
  active registration status.

**Everything ends the day BEFORE the training. One rule, no exceptions**, matching
`AffiliationServices::ApplyScenarioEndDating`
([ADR-0002](0002-org-linking-flows-and-agreement-scenarios.md) D4, which points back
here — one convention, two callers).

Two reasons, and the second is the one that matters:

1. A row ending the same day another starts counts on both, doubling the person in
   any report that totals a date.
2. **The row is being ended precisely because we have no record the person ever
   completed a training for this organization.** Ending it *on* the training date
   would leave it counting as active on that date — so the organization's status at
   that training would still rest on the affiliation we just decided wasn't valid.
   Ending the day before is what the decision actually means.

The consequence is that an organization whose only facilitator is ended this way
reads **Reinstated** at that training rather than Ongoing. That is not a cost being
paid for consistency: with the row gone there is no basis for Ongoing, and none of
the three labels describes "we removed the basis for their status" perfectly.
Reinstated is the honest one. Every earlier anchor is untouched, which is what D5's
stability promise is about.

An end date is never written before the row's own start date.

**This is also what lets reconciliation stop relying on the `inactive` flag.** The
minted row is deleted, so it can't linger; an older row ends the day before a
training that has already happened, so the date is always in the past and
`set_inactive_from_dates` derives the flag by itself. `deactivate` still sets it
explicitly, which is now belt-and-braces rather than load-bearing.

**What a deletion costs:** the row's comments go with it, so the "why" D6b records
survives only for ended rows. The deletion itself is still on the record as a
`destroy.affiliation` Ahoy event carrying the full attribute snapshot.

The org's *current* bucket is expected to change — that's the point. Its *anchored*
verdicts are not.

### D6a — A real lapse is a new row; an ending we made ourselves is reopened

**Revised 2026-08-24.** The original D6a said there is no `:reactivate` action at
all. That went too far: it produced two facilitator affiliations for one
organization in a case where nothing had actually lapsed, and the second row
implied an engagement that never ended and restarted. The distinction below is the
one that matters, and only the second half of the original decision survives.

**The invariant this serves:** a person never holds two facilitator affiliations
for the same organization describing one unbroken engagement. A second row exists
only when the first one genuinely ended — independently of the training being
reconciled — and this is a second engagement.

Two endings look alike in the data and mean opposite things:

- **An ending reconciliation applied for *this* training.** The person was recorded
  as not having completed it, so we ended the row by inference. When their
  attendance is corrected — a roster filled in late, a no-show reversed — that
  inference is simply wrong. **Reopen the row** (`:reactivate` clears `end_date` and
  `inactive`). Nothing lapsed, so there is no gap to preserve and nothing to
  record with a second row; leaving the ending in place and minting one alongside
  would invent a break that never happened.
- **Any other ending** — an admin ended it, or an earlier training's reconciliation
  did. That records a real stretch that finished. **Leave it**, reason "Ended — a
  return is recorded as a new affiliation", and the return shows up as an ordinary
  `:create`. Reopening it would swallow the gap: `Jan 2023 – Jan 2024, Aug 2026`
  collapses to `Jan 2023`, and the organization retroactively reads Ongoing across
  years it was not running a program. The lapse is the fact the two rows exist to
  record — ADR-0001 D2 renders exactly that shape, and `CreateFromRegistration` has
  always minted a second row rather than extending an ended one.

**A reopen is tied to the training whose attendance changed, and only that one.**
Correcting the attendance for training A reopens the row A's reconciliation ended.
Attending a *later* training B while A's ending stands does not: the stretch really
did finish at A and restart at B, so B adds a row. Reconciling B never reaches back
into A's ending.

**Telling them apart takes two signals, both required.** The row's `end_date` is
exactly what reconciling this training would write (`deactivation_end_date`), **and**
it carries a D6b reconciliation comment. The date alone is not enough — an admin who
happens to end a row the day before a training must not have it silently reopened —
and the comment alone is not enough, because an earlier training's reconciliation
leaves the same topic behind on a row that really did lapse.

When the reopen applies, no `:create` is proposed for that person and organization.
The two are mutually exclusive by construction, which is what keeps the invariant
from depending on the admin picking the right button.

**The admin can still overrule it.** A reopen row offers three outcomes: reopen it
(the default), create a new one alongside instead, or leave it inactive. The
correction-versus-second-engagement call is a judgement about what really happened,
and the data cannot always settle it.

This remains the mirror of D6. D6 stops an ending from reaching too far back; D6a
stops a reactivation from reaching too far forward — but only reaching past an
ending that actually meant something.

### D6b — The reason a row changed lives in its comments

Reconciliation writes a comment on the affiliation it ends or creates, topic
`"Reconciliation"` (`ReconcilePerson::COMMENT_TOPIC`), naming the event and what it
did. No dedicated `inactive_reason` column: the affiliation editor and its history
already surface comments, and the topic is enough of a handle for the one place that
needs to branch on it — telling a row reconciliation ended from one an admin ended,
so the page stops labelling both "didn't attend".

The limit is that a **deleted** row takes its comments with it (D6), so for those
the trail is the `destroy.affiliation` Ahoy event and its attribute snapshot.

### D6c — `registered` is a gap in the record, not an outcome

After the event, a registration still marked `registered` means nobody filled the
roster in. `EventRegistration#attendance_recorded?` deliberately excludes it — only
`attended`, `incomplete_attendance` and `no_show` count as outcomes.

Reconciliation therefore **does nothing** to those rows and lists them under
"Attendance never recorded — set an outcome first". Deleting an affiliation because
the roster is blank would be acting on missing data, and the deletion is not
reversible. Cancelled and transferred-out are different: those are decisions
somebody made.

For `incomplete_attendance` the page shows the sign-in sheet day by day
(`Event#event_dates` × `EventRegistration#attendance_entries_on`). "Incomplete" is a
judgement someone recorded, and the logged times are the evidence behind it — an
admin deciding whether to delete a facilitator affiliation should see which days
were missed without leaving the page.

### D6d — A transfer moves the affiliation; it does not end it

Transferring to another event isn't a failure to complete one — the person is still
going to train, somewhere else. So the affiliation **follows them**: its start date
becomes the destination event's, and its `event_registration_id` re-points at the
destination registration.

Re-pointing the provenance is not cosmetic. The FK is the auto-vs-manual gate
(D2a), so a row dated to the destination event but still pointing at the source
registration would not be recognised as "the row this training minted" when the
destination is reconciled — it would be treated as an older row and end-dated.

The rules:

- **Which row moves** — this person's facilitator affiliation with this organization
  that has **no end date**. One decision per (person, organization), not one per row.
- **An already-ended row stays put.** It records a finished stretch. With no open row
  to move, the destination mints a fresh affiliation instead.
- **No destination recorded yet** (`transfer_destination_pending?`) — reported, not
  guessed at. There is no date to move to.
- **Destination linked to a different organization** — reported. Re-dating this
  organization's row to a training about another one would assert something false.
- **Chained transfers need no traversal.** A→B→C collapses when the second transfer
  is made (`EventRegistrationsController#transfer` points C straight at A), so the
  source's `transferred_to_registration` is already the final destination.

This is deliberately *not* one of `LinkSubmittedOrganization::SCENARIOS`. Those
describe what kind of linking is happening and run at link time; a transfer is an
attendance outcome discovered at reconcile time, with nothing being linked.

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
7. **`registered` after the event is reported, never acted on** — D6c, asserted on
   both the plan's reason and that the row survives.
8. **A transfer moves the row rather than ending it** — D6d: the open row re-dates
   and re-points, an ended row is left alone with a fresh one created at the
   destination, and a pending or differently-linked destination is reported.
9. **A return after a real lapse adds a row and leaves the lapse intact** — D6a,
   asserted on both the row count and the mid-gap verdict.
10. **A corrected no-show reopens the row this training ended, and adds nothing** —
    D6a, asserted by reconciling twice across the attendance change: the row count
    must not move, and the row must come back active. Paired with a row an admin
    ended on the same date, which must NOT reopen.

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
