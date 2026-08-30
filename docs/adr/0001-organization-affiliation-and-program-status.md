# ADR-0001 — Organization affiliation dates & program status

- **Status:** Accepted
- **Date:** 2026-08-03

## Context

The organization profile/edit page surfaces several affiliation-derived figures
that are easy to confuse with one another:

- **Affiliated since**
- **Facilitators since**
- an org-wide **status chip** (Active / Upcoming / Formerly active / Never
  active; non-admins see Upcoming as "Inactive")
- per-event **program-status chips** (New / Ongoing / Reinstate)

Several code paths compute overlapping-but-distinct classifications with subtle
differences — different reference dates, whether the "registrant's own"
affiliation is excluded, and strict-vs-inclusive date boundaries. We kept
re-deriving these rules from scratch. This ADR pins the definitions and the
decisions that resolve the ambiguities so they're written down once.

## Vocabulary

- **Affiliation** — an Org ↔ Person link (`affiliations` table) with `title`,
  `start_date`, `end_date`, and a cached `inactive` flag. **Not tied to any
  event** (there is no `event_id` on an affiliation). **Refined by
  [ADR-0003](0003-affiliations-as-the-record-of-two-relationships.md) D2a:** still no
  `event_id`, but there is now an `event_registration_id` recording which
  registration minted the row.
- **Facilitator affiliation** — an affiliation whose `title` is **exactly
  `"Facilitator"`** (trimmed, case-sensitive). No fuzzy/`LIKE` matching; "Lead
  Facilitator" and "facilitator" do **not** count. See `Affiliation#facilitator?`
  and the `.facilitators` scope.
- **Active affiliation** — `inactive == false`, **started** (`start_date` is null
  or `<= today`), **and** not ended (`end_date` is null or `>= today`). A row whose
  `start_date` is still in the future is **Upcoming**, not Active. `inactive` is a
  cached column derived from the end date on save (`set_inactive_from_dates`:
  `inactive = end_date.present? && end_date < today`). See `Affiliation#active?` /
  `#status_on` and the `.active` scope.
  **Superseded in part by [ADR-0003](0003-affiliations-as-the-record-of-two-relationships.md)
  D2:** `inactive` is an override rather than a cache, so it can end a row the
  dates still call active — "active" no longer reduces to the dates.
- **Upcoming affiliation** — `inactive == false` and `start_date > today` (a
  facilitator scheduled but not yet started, e.g. dated to a future training). See
  `Affiliation#upcoming?`. The looser `.active_or_pending` scope counts Active
  **and** Upcoming together (used for registration dedup); `.active` counts Active
  only.
- **Facilitator-training event** — `events.facilitator_training == true`. The
  only events for which per-event program status is meaningful.

## Decisions

### D1 — "Affiliated since": all affiliations, org-only

Keyed off **all** of the org's affiliations (any title), with **nothing to do
with a registrant**. Rendered as merged year-based periods
(`AffiliationPeriods.label`), e.g. `2010-2012, 2026`; falls back to the org's own
`start_date`, then blank. See `OrganizationDecorator#affiliated_since_display`.

### D2 — "Facilitators since": facilitator affiliations only, month precision

*Formerly labeled "Art program since" in the UI; the decorator method is still
`program_since_display`, so code, old references, and the current label all name
the same figure.*

Same merged-period rendering as D1 but over **facilitator** affiliations only,
and at **month** precision (`AffiliationPeriods.label(…, precision: :month)`) —
when facilitating started or lapsed is the point of the figure. Ongoing reads
`Feb 2024`, closed reads `Aug 2015 – Jun 2018`, e.g.
`Aug 2015 – Jun 2018, Feb 2024`. Blank when the org has never facilitated. See
`OrganizationDecorator#program_since_display`.

**One value on every surface** (index chip, profile, edit form). The edit form
previously rendered its own earliest-start→latest-end span, which collapsed a
lapse-and-return into a single unbroken range and hid the gap; that is why this
is a single decorator method rather than per-page view logic.

### D3 — Org-wide status chip: Active / Upcoming / Formerly active / Never active

Four display buckets (`OrganizationDecorator#organization_status_bucket`), **not
event-relative**, derived from **facilitator affiliations only** and checked in
precedence order:

- Any **active** facilitator affiliation → **Active**
- Otherwise any **upcoming** (future-start, not yet started) facilitator
  affiliation → **Upcoming**
- Facilitator affiliation(s), but **all ended** → **Formerly active**
- **No** facilitator affiliation → **Never active**

Upcoming is distinct from Formerly active: an org whose only facilitator is
scheduled for a future training was never active, so it must not read as
"Formerly active".

The stored `OrganizationStatus` column plays **no part**. It is legacy data that
was maintained by hand and drifted; an org is "active" because someone is
facilitating there, not because a column says so. The same rule backs the index
filter (`Organization.program_status`), so the filter and the chip agree.

**The filter dropdown has one more option than the chip.** For an admin the chip
is only ever one of the four buckets above, so **Inactive is a filter option, not
an admin chip value** (non-admins are the exception — see the audience rule
below). Both the organization index and the people directory offer five, in this
order —
**Active / Inactive / Upcoming / Formerly active / Never active**
(`Organization::PROGRAM_STATUS_FILTER_OPTIONS`,
`Person::FACILITATOR_STATUS_FILTER_OPTIONS`).

**"Inactive" is the not-active umbrella.** It returns everyone/every org that is
not a currently-active facilitator — Formerly active, Never active (no
facilitator affiliation at all), **and Upcoming** — because none of them are
active right now
(`Organization.program_status("formerly_or_never")`, `Person.facilitators_inactive`).
Upcoming and Formerly active are the narrower options inside it. So an upcoming
org/person shows an *Upcoming* chip to an admin and is still found when you filter
by Inactive.

**Upcoming is an admin-only chip.** Non-admins see a not-yet-started program as
plain **"Inactive"**, coloured neutrally like Never active (it has never
facilitated) — the org index is becoming more than admin-facing and must reflect
the state of the world *today*, not a scheduled future one. Admins keep the
Upcoming chip, which is the operationally useful distinction. The bucket itself
is unchanged; only the label and colour collapse
(`OrganizationDecorator#organization_status_label(admin:)`), and
`.status_bucket_styles(admin:)` takes the same flag so the edit form's live chip
can't disagree with the server render for a non-admin owner.

On the edit form this chip **live-updates** from the visible facilitator rows.

### D3a — The legacy status column: flagged, never consulted

`OrganizationStatus::PROGRAM_STATUS_BUCKETS` survives for one purpose: bucketing
the stored value (`Active`/`Reinstate` → active, `Inactive`/`Suspended` → formerly
active, `Pending`/`Unknown`/missing → never active) so the **org edit form** can
show a warning where it contradicts the affiliations
(`OrganizationDecorator#legacy_status_mismatch?`). Nothing else reads it. Expect
the warning on a fair number of orgs — that is the drift it exists to surface.

The column has no **Upcoming** of its own, so a derived `:upcoming` is compared
as `:never_active`: a scheduled-but-not-started program is fairly recorded as
`Pending` (or blank/`Unknown`, which bucket with it), and only a stored
`Active`/`Reinstate` or `Inactive`/`Suspended` counts as drift.

### D4 — Program status: New / Ongoing / Reinstate, judged on one anchor date

**One value per (organization, anchor date)**, computed over **all** of the org's
facilitator affiliations by a single class, `FacilitatorProgramStatus`:

- **New** — no facilitator affiliation started **before** the anchor (strict `<`).
  An affiliation dated **on** the anchor is the one this event mints (D8), so a
  first-time org reads New at its own training — including a **same-day**
  (`start == end`) affiliation dated to the event.
- **Ongoing** — an earlier facilitator affiliation is **still active** on the
  anchor (no end date, or it ends on/after it).
- **Reinstated** — earlier facilitator affiliation(s) existed but **all ended**
  before the anchor (a lapse, now returning).

`Organization#facilitator_program_status(as_of:)` returns that object;
`#facilitator_status_on(date)` is the bare symbol for counting and filtering.
Nothing else classifies a program — the dashboard breakdown, the onboarding
matrix, the rosters, the org profile/edit chips, the **scholarship index** and
the annual report all call this one method, so they cannot disagree.

**Each row picks its own anchor.** The scholarship index anchors each award on
the start date of the training it paid for (`Scholarship#event`, via
allocation → event registration), so two awards listed side by side are judged
at their own events rather than at one page-wide "now". An award with no
registration behind it (grant-first, or funding a CE registration) falls back to
the year anchor, which `#explanation` labels "no event in view".

The status object also carries **why**: the anchor date, the month the program
went (or last was) active, and the full facilitator history as merged periods
(`AffiliationPeriods`). `#explanation` renders that as one sentence, which every
display hangs on the badge as hover text.

The symbols are `:new` / `:ongoing` / `:reinstated`, and `#label` is the one
display word — "New", "Ongoing", **"Reinstated"**. (The scholarship index's
separate `Organization#program_status(recipient)` says "Reinstate"; that string is
not this vocabulary.)

### D5 — Per-event, not per-registrant: no self-exclusion

Program status includes **all** of the org's facilitator affiliations, including
those held by the registrants at the event. We do **not** exclude "the
registrant's own affiliation."

The old per-registrant framing ("was the org already a program *before I
joined*?") is dropped. Two versions of it existed —
`EventRegistration#program_statuses` excluded the registrant's own affiliation as
of the event date, while `EventDashboard#program_status_for` re-anchored on that
affiliation's own start date — so the same org at the same event could read
Ongoing on the onboarding matrix and New in the dashboard pie, and the dashboard's
answer moved when a different registrant signed up. Both now ask the per-event
question: "at this event, was the org New / Ongoing / Reinstate?"

**What makes this safe:** the affiliation a training mints starts **on the
training date** (D8), and "before" is strict, so a first-time organization still
reads New at its own first training without any exclusion.

### D6 — Per-event chips only on facilitator-training events

The org-profile per-event chips render **only** for events where
`facilitator_training == true` (among the events the org is represented at via
active registrations). Attendance at a non-training event does **not** produce a
program-status chip — this is what stops attendance-only events from reading
"New" or "Reinstate".

### D7 — The anchor date: the event's start date, else January 1

The classification anchors on the event's actual `start_date` (not the 1st of its
month, not "today"), so revisiting a past event always reports what was true then.

**With no event in view** — the cross-event attendees roster and its breakdowns —
there is no event date to anchor on, so the status reads as of **January 1 of the
current year**: where each program stands this reporting year.
`FacilitatorProgramStatus` applies that fallback itself and flags `year_anchored?`,
and those views carry a caveat saying so. Any column showing a status names its
anchor: "Program status (TOS205)" in event context, with a hover giving the exact
date.

**The fallback is for surfaces that genuinely span events, not for every
cross-event class.** `AttendeesBreakdowns` backs both the cross-event attendees
index *and* one event's scholarship-recipients charts, so it takes an `as_of:`: the
recipients frame passes that event's `start_date` and reports the same verdicts its
dashboard does, while the index leaves it nil and gets the year anchor. A
single-event surface reaching for the year fallback is a bug — it makes the same
org read two ways at the same event, and the column's own note then describes a
basis the numbers don't have.

### D8 — Registration mints the facilitator affiliation, dated to the training

A facilitator-training registration creates the registrant's Facilitator
affiliation at submission time (`AffiliationServices::CreateFromRegistration`,
from both the public registration flow and admin org-linking), with
`start_date = event.start_date`. Dating it to the training rather than to the
submission is what lets D5 drop self-exclusion: the minted row is never "prior
history" for its own training. An event with no start date is the one gap — the
affiliation then falls back to the creation date. That event has no anchor either,
so both its dashboard and the annual report read it as year-anchored (D7) rather
than one of them silently using "today".

### D9 — Annual reporting counts organizations two ways

`EventProgramStatusReport` (the "Program status" report page, alongside revenue /
participation / scholarships) reports, per facilitator training and grouped by
calendar year:

- **Organization-trainings** (the row and year totals) — one count per
  organization **per training**, using that training's own anchor date. An org at
  three trainings in a year counts three times. This is the per-event figure that
  adds up across a year.
- **Distinct organizations** — each organization counted **once** for the period,
  classified at the **earliest** training it appeared at. This is "how many
  distinct programs did we touch, and what were they when we first saw them."

Both are shown, always labelled, because they answer different questions and only
coincide when no organization attended twice.

## The classifiers (map)

| Method | Role |
|---|---|
| `FacilitatorProgramStatus` | The rule. Verdict + anchor + reasoning. |
| `Organization#facilitator_program_status(as_of:)` | Entry point; reads preloaded affiliations. |
| `Organization#facilitator_status_on(date)` | The bare symbol, for counting/filtering. |
| `Organization#program_status(recipient)` | Scholarship-index string variant, **recipient-relative** — a distinct context (see below). |

## Boundary conventions

- **Strict `<`** for "earlier": `start_date == anchor` is **not** earlier (so the
  affiliation a training mints is **New**, not Ongoing).
- **Active-at-date** uses `end_date IS NULL OR end_date >= anchor`. Spelled
  `Affiliation.active_by_date_on(date)` since ADR-0003 D3 — the `historical` in the
  name marks it as the dates-only reader.

## Notes / open items

- **Scholarship `program_status(recipient)`** stays recipient-relative (it
  excludes the recipient's own affiliations to answer a scholarship-specific
  question). It is intentionally **not** covered by D5; reconcile with the
  per-event model later if the two need to agree.
- **Legacy affiliation dates are the one risk in dropping self-exclusion.** D5 is
  safe for anything minted since #2176, which dates the row to the training (D8).
  **Rows created before that may still be dated to the 1st of the month**, so a
  registrant's own affiliation can precede a same-month training and read that org
  as Ongoing where it should be New. Worth a one-off count of facilitator
  affiliations dated to the 1st that precede a training the same month before
  trusting a historical year's New figures.
- **What creates a facilitator affiliation:** since #2194 only a facilitator
  *training* registration mints one (non-training registrations get a job
  affiliation instead), and the row records its creating `event_registration_id`.
  That makes the D3 status buckets — which now key off facilitator affiliations
  alone — a read on training participation rather than on any registration.
