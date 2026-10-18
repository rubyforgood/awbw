# ADR-0008 — Importing FileMaker organizations, projects and personnel

- **Status:** Proposed
- **Date:** 2026-10-17

## Context

The Rolodex pass (`fm:import_people`, PR #2630) brings FileMaker contacts in as people:
their profile, tags, and home/mailing addresses and phones. It deliberately leaves out
everything that ties a person to an organization — job titles, facilitator assignments,
and work addresses — so they can arrive with the organizations they belong to. This is
that second pass.

The archive tables involved (row counts from the export):

| Archive table | Rows | What a row is |
|---|---|---|
| `fm_organizations` | 7,191 | An umbrella organization or agency (`OrgID`, `ParentID`) |
| `fm_projects` | 1,976 | One art program run at an organization (`ProjectID`, `OrgID`) |
| `fm_personnels` | 8,907 | A person assigned to a project, with role and agreement status (`PersonID`, `ProjectID`) |
| `fm_people_to_organizations` | 1,127 | A person's job at an organization, with title (`PersonID`, `OrgID`) |

Constraints already decided elsewhere:

- **An app Organization is usually a FileMaker Project** (one art-program site); a FileMaker
  Organization is the umbrella above it and maps to the parent in the nested-org tree
  (ADR-0004, ADR-0005).
- **Codes are sets.** `organizations.filemaker_code` and `affiliations.filemaker_code` hold
  several codes and match by intersection (ADR-0005, `FilemakerCoded`). Many existing orgs
  and affiliations already carry `P…` / `ORG…` codes from earlier migrations.
- **FileMaker is not the blanket source of truth** — staff edited both systems, so truth is
  per field.
- **Facilitator affiliations are minted from facilitator trainings** going forward; the
  reconcile page can end affiliations a training no longer backs.

## Decision (proposed)

- **Order:** people (#2630) → organizations → projects → affiliations. Each pass finds the
  records the previous one created by `filemaker_code`, so each is idempotent on its own.
- **Organizations and projects:** an `fm_projects` row becomes (or links to) an app
  `Organization`; its `fm_organizations` row becomes (or links to) that org's parent.
  Match an existing org by any shared `filemaker_code` first, then by exact name; append
  the code on a match, as the Rolodex pass does for people.
- **Personnel → facilitator affiliation:** an `fm_personnels` row becomes an `Affiliation`
  between the person (by Rolodex code) and the project's org, carrying `PrsnlRecID` as its
  `filemaker_code` so each row imports once. `Role` → `title`; `Status` / dates →
  `start_date` / `end_date` / `inactive`. `event_registration_id` stays NULL — these are
  historical, not training-minted.
- **People-to-organizations → job affiliation:** an `fm_people_to_organizations` row becomes
  an `Affiliation` to the umbrella org with its `Title`, carrying `RecordID` as its code.
- **Work addresses:** the Rolodex `WorksiteAddrsID` address and any address typed Work
  become an `Address` on the organization, and the person's affiliation there points at it
  (`affiliations.organization_address_id`).
- **Conflicts:** same rule as people — fill blanks, keep the portal value where the archive
  disagrees, and report each difference as a comment plus in the task output.
- **Out of scope:** event registrations (`fm_participants`, 68,497 rows), payments, funding,
  notes and activities — each its own pass.

## Open questions

- **Which org does a job affiliation attach to** — the umbrella (`fm_organizations`) or the
  person's project at that org, when there is exactly one?
- **Reconcile vs. history.** The reconcile page ends facilitator affiliations no attended
  training backs, hand-entered ones included. Imported personnel rows would be swept up
  unless they're exempted (e.g. by their `PS…` code) — exempt them, or let reconcile end
  them?
- **Which `Status` / `AgreementStatus` values mean active**, and is a closed project
  (`CloseDate`, `EndDate`) an end date for every affiliation under it?
- **Merged projects** (`MergerWithID`): fold the merged-away project into the survivor's
  org, or skip it?
- **Unmatched people:** a personnel row whose `PersonID` no person carries — skip and
  report, or create the person from the Rolodex row on the spot?
