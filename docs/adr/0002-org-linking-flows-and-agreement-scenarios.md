# ADR-0002 — Org linking: one core, three flows, and what each does to affiliations

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

Admins link a person's submitted organization from two editors: the event
registration one (registrants roster) and the standalone form submission one.
The collaboration agreement was split into three public forms, one per intake
scenario (`Form::PURPOSES`: on-demand training, reinstatement, job change), and
each scenario means something different for the person's *existing*
affiliations. Meanwhile event registrations already had their own rules. This
ADR pins which flow does what, and why the submission side records links the
way it does.

## Vocabulary

- **Linking scenario** — one shared vocabulary for what linking does to
  affiliations, across both flows: `on_demand`, `facilitator_training`,
  `reinstatement`, `job_change`, `non_facilitator_training`
  (`OrganizationServices::LinkSubmittedOrganization::SCENARIOS`). The first
  four confer the Facilitator affiliation; the last doesn't.
- **Agreement scenario / purpose** — `forms.purpose`, one of `Form::PURPOSES`
  (`on_demand`, `reinstatement`, `job_change` — the stored value IS the linking
  scenario name). Marks a standalone public form as one of the three
  collaboration agreement intake scenarios. Copies never inherit it
  (`FormCopyService` clears it), so a scenario is claimed by at most the forms
  an admin deliberately assigns.
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

| Scenario | Source | Confers Facilitator | Dated to |
|---|---|---|---|
| `on_demand` | `forms.purpose`, **or** an on-demand facilitator-training event | yes | submission date / event start |
| `facilitator_training` | scheduled facilitator-training event | yes | event start |
| `reinstatement` | `forms.purpose` | yes | submission date |
| `job_change` | `forms.purpose` | yes | submission date |
| `non_facilitator_training` | any other event | no — job affiliation only | — |

The on-demand path is **one scenario** however it arrives — through the
agreement form (LMS completion) or an on-demand training event. Event
scenarios are **derived at call time** from the event
(`EventRegistrationsController#event_linking_scenario`), never stored on a
form: registration forms are reused across events, and
`events.facilitator_training` is the canonical event-side fact (it also drives
ADR-0001's program-status machinery) — a form-side purpose would be a second
source of truth that could contradict it. Unpurposed public forms have no
scenario and confer nothing. Being a facilitator is conferred by a training or
an agreement, never by merely attending an org-linked event.

### D3 — Per-scenario end-dating happens at linking time (submission flow only)

`AffiliationServices::ApplyScenarioEndDating`, run by the core before creation:

- **Job change** — the person's active affiliations at *other* organizations
  end, job and facilitator alike (they've left that org). The linked org's own
  rows are spared.
- **Reinstatement** — any still-active Facilitator affiliations end (a
  returning facilitator shouldn't have one; this trues up the data). Job
  affiliations are left alone everywhere; a missing job affiliation at the
  linked org is created from the submitted position.
- **On-demand** — nothing ends.

Event-registration linking never auto-ends anything. The processing panel's
manual per-affiliation **End** button remains for ending without linking.

### D4 — Scenario ends are dated the day before the agreement takes effect

`end_date = submission date − 1 day`. Two reasons: the old and new affiliations
never overlap (one active row per day), and a row ended "today" still counts as
active-or-pending until the day is over — it would make
`AffiliationServices::CreateFromRegistration` skip the fresh reinstatement
Facilitator affiliation as a duplicate. The panel's manual **End** button uses
the same date. Every affiliation a scenario ends is recorded on the submission
(`metadata.scenario_ended_affiliation_ids`) and flagged on the processing panel
("Ended by this agreement", with an edit link) — end-dating all other orgs on a
job change is deliberately blunt, and the flag is how a wrongly-ended row (a
multi-org facilitator changing only one job) gets corrected.

### D5 — "Linked" on the submission side is explicit-link OR name-match; no join table

A submission reads as linked when an org was explicitly linked to it, or when
an active affiliation matches the submitted name. The explicit link is an id
array in `form_submissions.metadata` (the `linked_registration_ids` pattern),
**not** a submission↔org join model — the event side already has
`EventRegistrationOrganization` for its richer needs (pin, autofill notes), and
a second join for the rarer standalone case wasn't worth the schema. Event
linking **back-applies** the explicit link onto the submission its pinning
rules pair with the org, so a typo'd name resolved to a differently-named org
reads as linked everywhere. Event-page **Unlink** deliberately does *not*
retract the back-applied link (it can't be told apart from one made directly in
the submission editor, and Unlink is scoped to the registration join only).
