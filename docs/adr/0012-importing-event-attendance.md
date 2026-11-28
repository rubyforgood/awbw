# ADR-0012 — Importing event attendance, and what each imported registration must carry

- **Status:** Proposed
- **Date:** 2026-11-27
- **Updated:** 2026-11-28 — March 2026 attendance and scholarships, the 2026 facilitator-affiliation
  cleanup, and test data
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
  both dated to the training and carrying FileMaker personnel codes. The FA is tied to the
  registration; a JA is tied only when this training created it.
- **One portal event per FileMaker event,** with its price set before any money is recorded. A
  draft copy made to hold money is never the answer.
- **Fees stay with the event they were paid for,** even when FileMaker later re-filed them under
  another training.
- **Scholarships come from FileMaker's scholarship event,** mapped by hand to portal grants that
  must have room for them.
- **Test people move to the Test event** before an import; anyone with money on a real training
  stays.
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

It was repaired with one-off scripts, run once and then removed (see PR #3050's history).
This ADR turns what those scripts had to decide into the rule for every future import.

## Decisions

### D1 — Both importers share one hydration step

FileMaker and CSV differ only in how they read rows. Once a row is matched to a person and an
event, the same service creates or fixes the registration and its associations. Its rules are
D2–D8. The CSV importer's current association code (`CaptureFromSubmission` for orgs and
affiliations) moves behind it rather than being duplicated in a FileMaker task.

- **FileMaker keeps three events per training:** its registrations, its scholarship list, and
  its CE list, each with its own `fm_participants` rows. One portal event takes all three.
- **FileMaker:** `fm:import_attendance EVENT=<portal event id> FM_EVENT=<registration E-id>
  FM_SCHOLARSHIP=<E-id> FM_CE=<E-id>`, shaped like `fm:import_personnel` (dry run by default,
  rerunnable, report saved). The ids for each training are in the table below.
- **CSV:** `EventRegistrationImporter`, unchanged as an upload, calling the shared step.

### D2 — The event

- One portal event per FileMaker training; its abbreviation is the FileMaker code (TAC261).
- Its price and CE settings are set before money is recorded. If two portal events represent
  one training, fold them into one first; don't import into either.
- **Folding two events into one:** keep the event that holds the money. Move everyone else's
  registrations onto it; a moved registration keeps its id, so its ticket link and history
  stay. A person registered on both keeps the registration on the kept event and gets the
  earlier sign-up date, which their ticket shows as "Registered on". The other copy is deleted
  only if it holds no money, attendance, or records worth keeping; otherwise the two are merged.
- **Test registrations** move to the Test event (portal event 5) before anything is imported, so
  they never pick up affiliations or count toward a real training (decided 2026-11-28):
  - Their form submissions, form completions, topic subscriptions, emails, the local copies of
    their Stripe charges, and the Ahoy history that names the training move with them. Changes
    to the training's own record stay.
  - Their FAs move too: dated to the Test event's start and tied to its registration.
  - Someone holding a payment on a real training stays put: the money belongs to that training.
  - Several registrations for one test person fold into one on the Test event (the registration
    merge).
  - Throwaway test people merge into one test person. Test people that act out a scenario
    (a payer, a scholarship path, no organization) stay separate as examples.
- **Staff registrations** are removed at staff's request, the same way.

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
- **Recording it:** a registration still "registered" after the training becomes Attended when
  FileMaker's `Attended` field is 1, with every day box ticked, so a later day toggle on
  Onboarding can't walk the status back (2026-11-28).
- **The portal's own outcome wins.** A registration already cancelled, transferred out, or
  marked no-show keeps that status even when FileMaker says attended; it's listed instead. A
  portal registration with no FileMaker row is left alone and listed (2026-11-28).
- **Trained at a later session:** when FileMaker moved them to a later training, record a
  transfer. The first registration is transferred out, and the later one is attended. This also
  applies to someone who registered for one training and simply trained at the next.

### D5 — The linked organization

Every registration gets one, active or not. The first rule that names exactly one organization
wins:

1. **Transferred out:** the organizations on their later registration.
2. **Their FileMaker training row's** organization.
3. **The candidate matching the organization name they typed** on the portal registration form.
4. **The one organization every current source agrees on.** Sources are: their FileMaker
   contact record, person-to-organization links, personnel projects, FileMaker forms and
   payments, their current portal affiliations, and a portal organization at their work email's
   domain (never a free mail domain).

Otherwise the registration is listed for staff with every candidate and where it came from. A
FileMaker organization with no portal match is listed by name and code.

- Linking goes through the same service as the registration's link-organization page, so the
  affiliations follow D6–D8.
- A FileMaker code found on more than one portal organization isn't a choice to make. The fix is
  taking the stray code off the wrong organization.

### D6 — The job affiliation

When FileMaker has a title for them at that organization (contact record first, then
person-to-organization link):

- **Held with that title:** keep it.
- **Untitled one held:** give it the title. Don't add a second.
- **A different title held:** leave it and list it.
- **None held:** add one, tied to the registration.

A JA the person already held stays untied: the training didn't create it (decided 2026-11-27).

Its start is the day they signed up for the training (the registration's sign-up date), which
is the first time we knew about the job, live or on-demand, attended or not (decided 2026-11-28).
A blank start becomes the sign-up date; any other start, the 1st of a month included, is left
alone. An import never sets or clears a JA's end date; only closing it from
the profile ends it (decided 2026-11-28).

### D7 — The facilitator affiliation

Only for someone who completed a training (ADR-0003 D1: only an attended training confers
facilitation). It is created when the registration is marked Attended, not when they register
(decided 2026-11-27).

- Tied to the registration of the training they completed: the later one for a transfer.
- Starts on that training's start date. An on-demand training has no fixed start, so it starts
  on the day they completed it.
- **One active one, not tied:** tie it and date it; don't add a second. Keep its FileMaker
  code.
- **More than one active:** list it; staff choose which stays.
- **Only ended ones:** keep them ended and add a new one for this training. An import never
  clears an end date (ADR-0003 D6a).
- **Didn't complete, but holds an active one:** list it; don't change it.
- **An ended FA is never deleted,** by an import, a merge, or a cleanup. It is the record of when
  someone facilitated, which program history depends on (decided 2026-11-27).
- **An FA no training backs is deleted,** ended or not: someone who registered for a training
  for that organization but completed none (no-show, cancelled, transferred out, partial) never
  facilitated, so the row records nothing. Each deletion is its own `destroy.affiliation` Ahoy
  event, which keeps the row's fields (decided 2026-11-28).
  - Read completion from the person's training registrations for that organization, not from
    the FA's own registration link. Training FAs made before 2026-08-14 have no link, so a
    missing link doesn't mean hand-entered.
  - Keep FileMaker FAs, FAs whose person is still "registered" for a training (upcoming, or
    attendance not yet recorded), and FAs with no training registration at all.
  - A partial attendance counts as not completed here, so its FA goes. The Reconcile
    affiliations page still ends a partial attendee's FA rather than deleting it; the two
    should agree.
  - Deleting an organization's last active FA turns the organization Inactive (its own audit
    event), so the dry run lists the organizations that would change.

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
- Scholarships are recorded as scholarships, not as payments.

### D9a — Scholarships (decided 2026-11-28)

- **Amount and funder come from the training's scholarship event,** not the registration row.
  Each row there reads like "$1000 Funder A". The registration row's fee doesn't hold up: some
  say "Full Scholarship" beside a fee of 1000, and some fees are negative.
  - "$400 Funder B/$1100 Funder B" is two awards.
  - With no amount there, use the registration row's note ("Scholarship granted 750 [funder]").
- **Funder to grant is mapped by hand.** Portal grants carry no FileMaker code, so each funder
  name is matched to a portal grant before the run. "Unfunded" means no grant.
- **A grant can't pay past its amount.** Check every grant's room in the dry run and stop if any
  is over. When a grant is short, staff add an overflow grant; awards fill the first grant
  exactly and the rest goes to the overflow, splitting an award in two where needed.
- **Each award is** accepted and capped at what the registration still owes. For a training
  that's over, its tasks are marked complete; open tasks would lock the attendee's certificate.
- **It goes on that training's registration,** even when the portal has it cancelled or
  transferred out. A transfer keeps one balance, so the award still counts where they went.
- A registration that already has a scholarship is skipped.

### D10 — How every run behaves

- Dry run by default, then the same run applied. It prints counts by kind of change and a
  "for a look" list of everything skipped and why.
- Runs under its own `Current.source`, so the audit log names it. It sends no emails.
- Rerunnable: a second run changes nothing.

## Trainings and their ids

Which portal event each FileMaker training maps to. Internal ids only, no personal data. Add a
row before importing a training.

| Training | Code | Portal event | FileMaker registrations | Scholarships | CE |
|---|---|---|---|---|---|
| March 2026 | TAC261 | 19 | E3977 | E3979 | E3980 |
| July 2026 | TAC262 | 3 | E4026 | E4031 | E4032 |
| November 2026 | TAC263 | 7 | E4043 | E4044 | E4045 |
| On-demand 2026 | none | 6 | E4014 | none in 2026 | none |

On-demand has no training code; FileMaker files it by year ("Talent LMS On-Demand Facilitator
Training 2026"). Some years kept a scholarship list ("2023 On-Demand Scholarship Recipients",
E3772; 2025, E3931), so check for one before importing a year. On-demand courses such as
Trauma-Informed Practices are FileMaker "On-Demand Course" events, not facilitator trainings.

## Data changed under this ADR

Kinds of change only; the exact records are in the Ahoy audit log.

- **2026-11-27:** the March 2026 duplicate events folded into one.
- **2026-11-28:** facilitator affiliations created in 2026 with no completed training behind
  them deleted (D7). March 2026 attendance recorded from FileMaker (D4). March 2026
  scholarships created from its scholarship event (D9a). Test people moved to the Test event
  and merged (D2).

## Consequences

- **The CSV importer changes.** Its association code moves into the shared step, and gains D6's
  title-the-untitled rule, D7's tie-and-date rule, and D8's codes.
- **Registering for a scheduled training stops creating an FA.** Today a live training's FA is
  minted at registration, dated to the training. Under D7 it waits until the registration is
  marked Attended, the way on-demand trainings already do.
- **A training's attendance import waits on cleanup it can't do itself:** merging duplicate
  events and people, and taking stray FileMaker codes off organizations.
- **Placeholder dates are fixed only for the trainings an import touches.** Older ones stay
  until their training is imported.
- **March 2026 attendance was recorded without D7.** Marking a registration Attended doesn't
  create or tie an FA yet, so March's attendees still need their FA tied to the March
  registration and dated to the training when the attendance import runs.
- **The CSV importer's scholarships fall short of D9a.** It awards with no grant and leaves
  tasks open, so a past training's certificates lock until staff tick each one. The shared step
  takes a funder-to-grant map and marks a past training's tasks complete.
