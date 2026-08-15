# ADR-0001 — Organization affiliation dates & program status

- **Status:** Accepted
- **Date:** 2026-08-03

## Context

The organization profile/edit page surfaces several affiliation-derived figures
that are easy to confuse with one another:

- **Affiliated since**
- **Facilitations/program since**
- an org-wide **status chip** (Active / Formerly active / Never active)
- per-event **program-status chips** (New / Ongoing / Reinstate)

Several code paths compute overlapping-but-distinct classifications with subtle
differences — different reference dates, whether the "registrant's own"
affiliation is excluded, and strict-vs-inclusive date boundaries. We kept
re-deriving these rules from scratch. This ADR pins the definitions and the
decisions that resolve the ambiguities so they're written down once.

## Vocabulary

- **Affiliation** — an Org ↔ Person link (`affiliations` table) with `title`,
  `start_date`, `end_date`, and a cached `inactive` flag. **Not tied to any
  event** (there is no `event_id` on an affiliation).
- **Facilitator affiliation** — an affiliation whose `title` is **exactly
  `"Facilitator"`** (trimmed, case-sensitive). No fuzzy/`LIKE` matching; "Lead
  Facilitator" and "facilitator" do **not** count. See `Affiliation#facilitator?`
  and the `.facilitators` scope.
- **Active affiliation** — `inactive == false` **and** (`end_date` is null or
  `>= today`). `inactive` is a cached column derived from the dates on save
  (`set_inactive_from_dates`: `inactive = end_date.present? && end_date < today`),
  so in practice "active" reduces to **no end date, or end date ≥ today**.
- **Facilitator-training event** — `events.facilitator_training == true`. The
  only events for which per-event program status is meaningful.

## Decisions

### D1 — "Affiliated since": all affiliations, org-only

Keyed off **all** of the org's affiliations (any title), with **nothing to do
with a registrant**. Rendered as merged year-based periods
(`AffiliationPeriods.label`), e.g. `2010-2012, 2026`; falls back to the org's own
`start_date`, then blank. See `OrganizationDecorator#affiliated_since_display`.

### D2 — "Art program since": facilitator affiliations only, month precision

Same merged-period rendering as D1 but over **facilitator** affiliations only,
and at **month** precision (`AffiliationPeriods.label(…, precision: :month)`) —
when a program started or lapsed is the point of the figure. Ongoing reads
`Feb 2024`, closed reads `Aug 2015 – Jun 2018`, e.g.
`Aug 2015 – Jun 2018, Feb 2024`. Blank when the org has never facilitated. See
`OrganizationDecorator#program_since_display`.

**One value on every surface** (index chip, profile, edit form). The edit form
previously rendered its own earliest-start→latest-end span, which collapsed a
lapse-and-return into a single unbroken range and hid the gap; that is why this
is a single decorator method rather than per-page view logic.

### D3 — Org-wide status chip: Active / Formerly active / Never active

Three display buckets (`OrganizationDecorator#organization_status_bucket`), **not
event-relative**, derived from **facilitator affiliations only**:

- Any **active** facilitator affiliation → **Active**
- Facilitator affiliation(s), but **all ended** → **Formerly active**
- **No** facilitator affiliation → **Never active**

The stored `OrganizationStatus` column plays **no part**. It is legacy data that
was maintained by hand and drifted; an org is "active" because someone is
facilitating there, not because a column says so. The same rule backs the index
filter (`Organization.program_status`), so the filter and the chip can't disagree.

On the edit form this chip **live-updates** from the visible facilitator rows.

### D3a — The legacy status column: flagged, never consulted

`OrganizationStatus::PROGRAM_STATUS_BUCKETS` survives for one purpose: bucketing
the stored value (`Active`/`Reinstate` → active, `Inactive`/`Suspended` → formerly
active, `Pending`/`Unknown`/missing → never active) so the **org edit form** can
show a warning where it contradicts the affiliations
(`OrganizationDecorator#legacy_status_mismatch?`). Nothing else reads it. Expect
the warning on a fair number of orgs — that is the drift it exists to surface.

### D4 — Per-event program status: New / Ongoing / Reinstate

**One value per (org, event)**, keyed off the **event's start date**, computed
over **all** of the org's facilitator affiliations as of that date
(`Organization#facilitator_status_on` / `OrganizationDecorator#facilitator_status_as_of`):

- **New** — no facilitator affiliation started **before** the event date
  (strict `<`). An affiliation starting **on** the event date, if it is the org's
  first, reads **New**. _(e.g. event starts Feb 14, the org's first facilitator
  affiliation starts Feb 14 → New as of that event.)_
- **Ongoing** — an earlier facilitator affiliation is **still active** at the
  event date.
- **Reinstate** — earlier facilitator affiliation(s) existed but **all ended**
  before the event date (a lapse, now returning).

### D5 — Per-event status is per-EVENT, not per-registrant (no self-exclusion)

Program status includes **all** of the org's facilitator affiliations, including
those held by the registrants at the event. We do **not** exclude "the
registrant's own affiliation."

Previously `EventRegistration#program_statuses` and
`EventDashboard#program_status_for` excluded it (to answer "was the org already a
program *before I joined*"); that per-registrant framing is **dropped**. The
question is per-event: "at this event, was the org New / Ongoing / Reinstate?"

### D6 — Per-event chips only on facilitator-training events

The org-profile per-event chips render **only** for events where
`facilitator_training == true` (among the events the org is represented at via
active registrations). Attendance at a non-training event does **not** produce a
program-status chip — this is what stops attendance-only events from reading
"New" or "Reinstate".

### D7 — Reference date = the event's start date

The classification anchors on the event's actual `start_date`.

## Boundary conventions

- **Strict `<`** for "earlier": `start_date == event date` is **not** earlier
  (so a same-day first affiliation is **New**, not Ongoing).
- **Active-at-date** uses `end_date IS NULL OR end_date >= reference`.

## The classifiers (map)

| Method | Role |
|---|---|
| `Organization#facilitator_status_on(date, excluding_affiliation_id:)` | Canonical SQL classifier. |
| `OrganizationDecorator#facilitator_status_as_of(date)` | In-memory mirror for the org-profile chips. |
| `Organization#facilitator_status(affiliation)` | Thin wrapper — **no callers, retire it**. |
| `Organization#program_status(recipient)` | Scholarship-index string variant, **recipient-relative** — a distinct context (see below). |

## Consequences / follow-up code changes

1. **Remove self-exclusion (D5):** `EventRegistration#program_statuses` →
   `organization.facilitator_status_on(reference_date)` (drop the `own` lookup);
   `EventDashboard#program_status_for` collapses to
   `organization.facilitator_status_on(reference_date)`. Update their specs (they
   currently assert the exclusion).
2. **Gate org-profile chips to facilitator-training events (D6):** filter
   `@organization_events` by `facilitator_training: true`.
3. **Align the reference date (D7):** `EventRegistration#program_statuses`
   currently anchors on `event.start_date.beginning_of_month`; the org-profile
   chip and `EventDashboard#reference_date` use the raw `event.start_date`.
   Standardize on the **raw start date**.
4. **Retire** the dead `Organization#facilitator_status(affiliation)` wrapper.

## Notes / open items

- **Scholarship `program_status(recipient)`** stays recipient-relative (it
  excludes the recipient's own affiliations to answer a scholarship-specific
  question). It is intentionally **not** covered by D5; reconcile with the
  per-event model later if the two need to agree.
- **Affiliation date precision:** the raw-start-date anchor (D7) reads a
  month-precision affiliation (dated to the 1st) as Ongoing where the actual date
  would read New — which is why `program_statuses` originally used
  `beginning_of_month`. Newly minted affiliations are safe: #2176 changed both the
  registration-minted and manually added rows to use the actual date. **Rows
  created before that change may still be dated to the 1st**, so a historical
  same-month training can still classify as Ongoing.
- **What creates a facilitator affiliation:** since #2194 only a facilitator
  *training* registration mints one (non-training registrations get a job
  affiliation instead), and the row records its creating `event_registration_id`.
  That makes the D3 status buckets — which now key off facilitator affiliations
  alone — a read on training participation rather than on any registration.
