# ADR-0012 — Importing event attendance, and what each imported registration must carry

- **Status:** Proposed
- **Date:** 2026-11-27
- **Builds on:** [ADR-0003](0003-affiliations-as-the-record-of-two-relationships.md) (what an
  affiliation records), [ADR-0005](0005-filemaker-code-archive-mapping.md) (FileMaker codes),
  [ADR-0011](0011-filemaker-affiliations-import-one-table-at-a-time.md) (Personnel as facilitator
  affiliations)

## TL;DR

- **Two ways in, one result.** Attendance comes from the FileMaker archive (`fm_participants`)
  or from a CSV (`EventRegistrationImporter`). Both must leave every registration with the same
  associations, so both call one shared hydration step instead of each doing its own.
- **A registration is done when it has:** a linked organization; a job affiliation (JA) when
  FileMaker knows their title; a facilitator affiliation (FA) when they completed the training;
  both affiliations tied to the registration, dated to the training, and carrying FileMaker
  personnel codes.
- **One portal event per FileMaker event,** with its price set before any money is recorded. A
  draft copy made to hold money is never the answer.
- **Fees stay with the event they were paid for,** even when FileMaker later re-filed them under
  another training.
- **Everything runs as a dry run first,** skips what it can't decide, and lists it.

## Context

The March 2026 training (FileMaker TAC261, E3977) showed what goes wrong without a rule:

- Staff entered the roster by hand on an event with no price. Because a free event can't take
  payments, money went onto a draft copy of the event, so March existed twice.
- Most facilitator affiliations were made by hand or by the FileMaker import with no
  registration behind them, dated to placeholders (the 1st of the month, or Jul 1 where the
  import stamped one).
- Few job affiliations carried FileMaker's title; some were untitled.
- People FileMaker moved to the July training (TAC262) had no transfer in the portal. One fee
  was recorded twice in FileMaker (D29104 under TAC261, D29133 re-filed under TAC262).
- One FileMaker organization code sat on two portal organizations, so linking by code was
  ambiguous.

It was repaired with one-off console scripts (`.context/march/` in the workspace, and PR #3050).
This ADR turns what those scripts had to decide into the rule for every future import.

## Decisions

### D1 — Both importers share one hydration step

FileMaker and CSV differ only in how they read rows. Once a row is matched to a person and an
event, the same service creates or fixes the registration and its associations. Its rules are
D2–D8. The CSV importer's current association code (`CaptureFromSubmission` for orgs and
affiliations) moves behind it rather than being duplicated in a FileMaker task.

- **FileMaker:** `fm:import_attendance EVENT=<portal event id> FM_EVENT=<E-id>`, shaped like
  `fm:import_personnel` (dry run by default, rerunnable, report saved). Reads the training's
  `fm_participants` rows plus its scholarship and CE lists (TAC261 had E3977, E3979, E3980).
- **CSV:** `EventRegistrationImporter`, unchanged as an upload, calling the shared step.

### D2 — The event

- One portal event per FileMaker training; its abbreviation is the FileMaker code (TAC261).
- Its price and CE settings are set before money is recorded. If two portal events represent
  one training, merge them first; don't import into either.

### D3 — The person

- Match on the FileMaker participant id (`Person.with_filemaker_code`). Exactly one person must
  carry it.
- Several people carrying it, or a name already registered under another person record: stop
  for that row and list it. People are merged by hand (only on name and email, never on name
  alone).
- A FileMaker row with no status that says it paid for others is a **payer**, not a
  registrant. It gets no registration.

### D4 — The registration

- One per person per event. It carries FileMaker's registration id (`filemaker_code`) and
  FileMaker's entry date as `created_at`.
- **Completed** means attended in the portal, or FileMaker's status says "Attended". Attendance
  notes such as "Day 2 only" are ignored; the status decides (2026-11-27). A row that
  says "did not attend" is not completed.
- **Trained at a later session:** when FileMaker moved them to a later training, record a
  transfer. The first registration is transferred out, and the later one is attended. This also
  applies to someone who registered for one training and simply trained at the next.

### D5 — The linked organization

Every registration gets one, active or not. In order:

1. Transferred out: the organizations on their later registration.
2. The organization on their FileMaker training row.
3. The organization on their FileMaker contact record.

A FileMaker code found on more than one portal organization is skipped and listed. The fix is
taking the stray code off the wrong organization, not choosing between them.

### D6 — The job affiliation

When FileMaker has a title for them at that organization (contact record first, then
person-to-organization link):

- **Held with that title:** keep it.
- **Untitled one held:** give it the title. Don't add a second.
- **A different title held:** leave it and list it.
- **None held:** add one.

Its start is the training date of the training they completed, which is the first time we knew
about the job. A blank start, or the 1st of that training's month (a placeholder), becomes the
training date; any other start is left alone.

### D7 — The facilitator affiliation

Only for someone who completed a training (ADR-0003 D1: only an attended training confers
facilitation).

- Tied to the registration of the training they completed: the later one for a transfer.
- Starts on that training date.
- **One active one, not tied:** tie it and date it; don't add a second. Keep its FileMaker
  code.
- **More than one active:** list it; staff choose which stays.
- **Only an ended one:** leave it ended. An import never clears an end date (ADR-0003 D6a).
- **Didn't complete, but holds an active one:** list it; don't change it.

### D8 — FileMaker codes on affiliations

Both the FA and the JA carry the person's FileMaker personnel code(s) at that organization:
Personnel rows whose project is the organization's, whether the project code or the project's
organization code is on it. A JA whose title came from a person-to-organization link
(`fm_people_to_organizations`) also carries that link's code. Codes are comma-separated and
added to any already there, never replacing them (decided 2026-11-27).

### D9 — Money

- **Fees stay with the event they were paid for.** Allocate to that event's registration. A
  transfer carries the balance to the later registration (the one-balance rule for transfers).
- A payment FileMaker re-filed under another training counts once, at the training it paid
  for. Re-filed copies share a FileMaker code family and are merged, never double-counted.
- Group payments (one payer, several trainees) are allocated per trainee, from FileMaker's
  notes or the bulk payment's linked registrations. Unclear ones are listed, never guessed.
- Scholarships are recorded as scholarships, not as payments. FileMaker's fee on a scholarship
  row is what the person owed after the scholarship.

### D10 — How every run behaves

- Dry run by default, then the same run applied. It prints counts by kind of change and a
  "for a look" list of everything skipped and why.
- Runs under its own `Current.source`, so the audit log names it. It sends no emails.
- Rerunnable: a second run changes nothing.

## Consequences

- **The CSV importer changes.** Its association code moves into the shared step, and gains D6's
  title-the-untitled rule, D7's tie-and-date rule, and D8's codes.
- **A training's attendance import waits on cleanup it can't do itself:** merging duplicate
  events and people, and taking stray FileMaker codes off organizations.
- **Placeholder dates are fixed only for the trainings an import touches.** Older ones stay
  until their training is imported.
