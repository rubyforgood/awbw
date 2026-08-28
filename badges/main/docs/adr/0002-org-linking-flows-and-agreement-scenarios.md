# ADR-0002 — Org linking: one core, three flows, and what each does to affiliations

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

Admins link a person's submitted organization from two editors: the event
registration one (registrants roster) and the standalone form submission one.
The collaboration agreement was split by intake scenario — expressed through
**form roles**, not a stored purpose. On-demand intake is a `registration`-role
form connected to the current on-demand facilitator-training event: people fill
out that event's **public registration form** link (the full registration
pipeline), like any other training. `new_job` / `reinstatement` are their own
roles on standalone forms reached by **public `/f/` links**. Each scenario
means something different for the person's *existing* affiliations. Meanwhile event registrations already had their own rules. This
ADR pins which flow does what, and why the submission side records links the
way it does.

## Vocabulary

- **Linking scenario** — one shared vocabulary for what linking does to
  affiliations, across both flows: `on_demand`, `facilitator_training`,
  `reinstatement`, `new_job`, `non_facilitator_training`
  (`OrganizationServices::LinkSubmittedOrganization::SCENARIOS`). The first
  four confer the Facilitator affiliation; the last doesn't. Always **derived
  at call time**, never stored as its own column.
- **Agreement form roles** — `Form::AGREEMENT_ROLES`
  (`registration` / `new_job` / `reinstatement`). On-demand's primary intake is
  the on-demand training event's public registration form (an event
  registration, scenario from the event); a *standalone* public
  `registration`-role submission is only the fallback path — it maps to
  `on_demand` (`FormSubmission#linking_scenario`, `role: "public"` only) and
  auto-registers the person for `Event.current_on_demand_facilitator_training`
  so both paths converge. `new_job` and `reinstatement` map to themselves and
  are always standalone `/f/` forms.
- **Linking core** — `OrganizationServices::LinkSubmittedOrganization`: the
  shared work of both editors (fill-blanks profile + work-address sync,
  affiliation creation, conflict diff, flash text). Each editor keeps only a
  flow-specific wrapper.
- **Explicit link** — `FormSubmission#linked_organization_ids` (metadata): an
  admin's recorded resolution that this submission's organization is that org.

## Decisions

### D1 — One linking core, flow-specific wrappers

Both editors call the linking core; neither duplicates the sync/create/report
logic. The event flow's wrapper owns the `EventRegistrationOrganization` link
row, the submission pin, and the persistent autofill notes. The submission
flow's wrapper owns the explicit link. Anything that should behave identically
in both editors belongs in the core, not a wrapper.

### D2 — Five linking scenarios, one vocabulary, two stored discriminators

| Scenario | Confers Facilitator | End-dating |
|---|---|---|
| `on_demand` (registration for an on-demand facilitator-training event; the standalone public registration-role form is the fallback, which auto-registers) | yes — dated to event start / submission | none |
| `reinstatement` (form role) | yes — dated to submission, only when no active one exists | none |
| `new_job` (form role) | yes — dated to submission; the job affiliation is start-dated too | other orgs' affiliations |
| `facilitator_training` (scheduled facilitator-training event) | yes — dated to event start | none |
| `non_facilitator_training` (any other event) | no — job affiliation only | none |

The on-demand path is **one scenario** however it arrives — registering on
the on-demand training event's public registration form (the primary path) or
the standalone fallback form, which auto-registers; it is the registration
flow either way.
Event scenarios are derived from the event
(`EventRegistrationsController#event_linking_scenario`), never stored on a
form: registration forms are reused across events, and
`events.facilitator_training` is the canonical event-side fact (it also drives
ADR-0001's program-status machinery) — a form-side flag would be a second
source of truth that could contradict it. Non-agreement forms have no scenario
and confer nothing. Being a facilitator is conferred by a training or an
agreement, never by merely attending an org-linked event.

### D3 — Per-scenario end-dating happens at linking time (submission flow only)

`AffiliationServices::ApplyScenarioEndDating`, run by the core before creation:

- **New job** — the person's active affiliations at *other* organizations
  end, job and facilitator alike (they've left that org). The linked org's own
  rows are spared, and the fresh job + Facilitator affiliations both start on
  the submission date (the one case where a job affiliation gets a start date —
  the job demonstrably starts with the agreement).
- **Reinstatement** — nothing ends: it reconciles registration-style, creating
  the Facilitator (and, from the submitted position, job) affiliation only
  where no active one exists; an already-active row means nothing to do.
- **On-demand** — nothing ends.

Event-registration linking never auto-ends anything. The processing panel's
manual per-affiliation **End** button remains for ending without linking.

### D4 — Scenario ends are dated the day before the agreement takes effect

`end_date = submission date − 1 day`. Two reasons: the old and new affiliations
never overlap (one active row per day), and a row ended "today" still counts as
active-or-pending until the day is over — `AffiliationServices::CreateFromRegistration`
would skip the fresh affiliations as duplicates. The panel's manual **End** button uses
the same date. Every affiliation a scenario ends is recorded on the submission
(`metadata.scenario_ended_affiliation_ids`) and flagged on the processing panel
("Ended by this agreement", with an edit link) — end-dating all other orgs on a
new job is deliberately blunt, and the flag is how a wrongly-ended row (a
multi-org facilitator changing only one job) gets corrected.

### D5 — "Linked" on the submission side is a direct link only; no join table

A submission reads as linked only through a real link to an org — never because
the person happens to hold an affiliation whose org name matches what they
typed. Two links carry it: the explicit one in `form_submissions.metadata`, and
the `EventRegistrationOrganization` row this submission is pinned to
(`form_submission_id`, set by public registration and by the event editor).
**Both count everywhere** — the index's "Organization linking" filter and org
chip, `for_organization`, and the linking editor's matched org — because public
registration records only the pin, and counting the metadata alone left those
submissions in the "Pending" queue with nothing to action while the registrants
roster already called the same registration Linked
(`FormSubmission::DIRECT_ORG_LINK_SQL`). On the editor page only, rows predating
the pin fall back to the registration's **sole** linked org, the same single-org
rule the event editor pairs submitted answers by. An affiliation is
downstream of linking, not evidence of it: every path that links an org also
mints the affiliation, so the affiliation match only ever restated the link less
precisely — and it wrongly claimed a link for a name collision with an org the
person is affiliated with for unrelated reasons. The explicit link is an id
array in `form_submissions.metadata` (the `linked_registration_ids` pattern),
**not** a submission↔org join model — the event side already has
`EventRegistrationOrganization` for its richer needs (pin, autofill notes), and
a second join for the rarer standalone case wasn't worth the schema. Event
linking **back-applies** the explicit link onto the submission its pinning
rules pair with the org, so a typo'd name resolved to a differently-named org
reads as linked everywhere. Both indexes offer the same four values — Linked /
Unlinked / Pending / No org provided (`FormSubmission.org_link_status`,
`EventRegistration.organization_linking_status`) — so a registration and the
submission behind it can't be filed under different words.
Event-page **Unlink** deliberately does *not*
retract the back-applied link (it can't be told apart from one made directly in
the submission editor, and Unlink is scoped to the registration join only).
