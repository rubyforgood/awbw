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
| `fm_rolodexes` | 39,608 | The person's own card: their organization (`OrgID`, `Organization`), `Title`, worksite (`WorksiteAddrsID`); or, flagged `isAgency__c`, an agency's card |
| `fm_addresses`, `fm_phone_numbers`, `fm_email_addresses` | 28,398 / 33,915 / 29 | Contact rows, filed under a Rolodex card (`RolodexID`), an organization (`OrgID`), or both |

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
  `fm:import_organizations` runs organizations + projects
  (`OrganizationServices::ImportFromFilemaker`), then affiliations
  (`AffiliationServices::ImportFromFilemaker`).
- **Organizations and projects:** an `fm_projects` row becomes (or links to) an app
  `Organization`; its `fm_organizations` row becomes (or links to) that org's parent.
  Match an existing org by any shared `filemaker_code` first, then by exact name; append
  the code on a match, as the Rolodex pass does for people.
  - **An organization with exactly one project is one org**, carrying both codes — a parent
    with a single child would be the same place twice. Only an organization with several
    projects (or none) gets its own org with the programs nested under it. When the portal
    already keeps the two apart, it stays that way.
  - **A name match only reaches an org carrying no code from the same table.** One already
    holding another project's code is a namesake; the new org is named `"Name (P1234)"`,
    since org names are unique.
  - Every FileMaker organization comes over, whether or not a project or person points at it
    (decided 2026-10-24).
- **Agencies:** a Rolodex card flagged `isAgency__c` is the agency's own card. Its website,
  mission and addresses fill the org its `OrgID` names (or the one its `Organization` name
  matches, created when nothing does); its email too, unless the card names a contact
  person, whose email it then is. A card naming a contact person also becomes that person
  in the people pass, and every address on it stays with the org.
- **Personnel → facilitator affiliation:** an `fm_personnels` row becomes an `Affiliation`
  between the person (by Rolodex code) and the project's org, carrying `PrsnlRecID` as its
  `filemaker_code` so each row imports once. `event_registration_id` stays NULL — these are
  historical, not training-minted.
  - **Role:** a blank role or "Facilitator" is a Facilitator affiliation. A role naming more
    ("Lead Facilitator") is a Facilitator affiliation plus a job affiliation with that title,
    as registration mints them (ADR-0003 D1); any other role ("Supervisor") is a job
    affiliation alone.
  - **Dates:** Personnel rows carry none of their own, so the assignment starts on
    `DateEntered` and ends on the project's `CloseDate` (else `EndDate`). A `Status` outside
    `ACTIVE_STATUSES` ends it now, undated (`inactive`). The run tallies every Status value
    and how it was read, so the list can be corrected before the real run.
  - An existing same-title affiliation at that org is linked (takes the code, fills blank
    dates) unless it already records another Personnel row — a second stint stays its own row.
- **People-to-organizations → job affiliation:** an `fm_people_to_organizations` row becomes
  an `Affiliation` to the org carrying its `OrgID` code with its `Title`, carrying `RecordID`
  as its code. Undated, per ADR-0003 D1.
- **The Rolodex card → job affiliation:** the card's `OrgID` (or its typed `Organization`, via
  `NameMatcher`) and `Title` become a job affiliation there — the field `FmRolodex::PORTAL_FIELDS`
  already mapped to `affiliations.title`. No code: the card's ID is the person's.
- **Work addresses:** the Rolodex `WorksiteAddrsID` address, any address typed Work, and
  every address on an agency's card become an `Address` on the organization, and the
  person's affiliations there that name no address point at it
  (`affiliations.organization_address_id`), the worksite first. The organization is the one
  FileMaker filed the address under (its `OrgID`), else the card's, else the person's only
  one. A work address with no organization to land on stays with the person, typed work.
- **Locality and districts come from the project, not derived.** `fm_projects` is the one
  place FileMaker records a `Locality`, and its vocabulary is where `Address::LOCALITIES`
  came from — so a project's `Locality`, `District`, `SPA` and `LASupervisorialDistrict`
  copy straight onto the organization's address (`locality`, `district`,
  `la_service_planning_area`, `la_supervisorial_district`). Only a person's own address has
  no locality to carry, which is why the Rolodex pass works it out with `AddressLocality`.
  Those project rows also carry real County → Locality pairs, so they are where to read
  AWBW's Northern/Central/Southern line from instead of inventing it.
- **Conflicts:** same rule as people — fill blanks, keep the portal value where the archive
  disagrees, and report each difference as a comment plus in the task output.
- **Out of scope:** event registrations (`fm_participants`, 68,497 rows), payments, funding,
  notes and activities — each its own pass.

## Open questions

The first draft of the import (#2788) answers these provisionally; confirm or change before
the real run.

- **Which org does a job affiliation attach to** — the one carrying the `OrgID` code. For an
  organization with one project that's the program's own org, so the question only remains
  for organizations with several projects, where it's the umbrella.
- **Reconcile vs. history.** Still open. The reconcile page ends facilitator affiliations no
  attended training backs, hand-entered ones included, and imported personnel rows are
  hand-entered by that test. Exempt rows carrying a `PS…` code, or let reconcile end them?
- **Which `Status` values mean active** — provisionally "Active" and "Current"
  (`AffiliationServices::ImportFromFilemaker::ACTIVE_STATUSES`); the dry run's tally is the
  check. A closed project's `CloseDate` (else `EndDate`) ends every affiliation under it.
  `AgreementStatus` isn't read.
- **Merged projects** (`MergerWithID`): folded — the merged-away project's code joins the
  survivor's org, so its personnel land there. One the portal already keeps as its own org
  is reported for a hand merge rather than merged automatically.
- **Unmatched people:** skipped and reported.
