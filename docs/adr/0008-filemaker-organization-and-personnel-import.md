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
  - **Organization type** comes from the FileMaker organization's `OrgType`, else the
    project's `AgencyType`, first match winning: "501" or "nonprofit" → 501c3/nonprofit;
    "for-profit" or "LLC" → For-profit; "government" or "govt" → Government agency; "Other"
    → Other. Any other word ("School", "Educational Institution", "Individual", "Grassroots")
    is Other with the word as its description. A value naming two types, as FileMaker's
    multi-select stored them, takes the first.
  - Every FileMaker organization comes over, whether or not a project or person points at it
    (decided 2026-10-24) — except one staff retired by renaming it ("DELETE", "… Do Not Use",
    "created in error"). Those are listed by code in `FilemakerValues::RETIRED_RECORDS`
    (48 of prod's 53; the other 5 a portal org already carries, so they import) and skipped
    and reported. Most retired organizations are "X Do Not Use" duplicates whose Rolodex cards
    and jobs still point at them (82 cards in prod), so those 27 are mapped in
    `RETIRED_DUPLICATE_OF` to the one they duplicated and fold into it like a merged project:
    the code, blanks, addresses, phones and projects move over and what names the code lands
    there. The rest are skipped, their projects unnested (decided 2026-10-25).
- **Agencies:** a Rolodex card flagged `isAgency__c` is the agency's own card. Its website,
  mission and addresses fill the org its `OrgID` names (or the one its `Organization` name
  matches, created when nothing does); its email too, unless the card names a contact
  person, whose email it then is. A card naming a contact person also becomes that person,
  and every address on it stays with the org. `fm:import_people` skipped every agency card,
  so `fm:import_organizations` runs the Rolodex import over agency cards alone as its first
  step — the people already imported and cleaned up are left as they are.
- **Personnel → facilitator affiliation:** an `fm_personnels` row becomes an `Affiliation`
  between the person (by Rolodex code) and the project's org, carrying `PrsnlRecID` as its
  `filemaker_code` so each row imports once. `event_registration_id` stays NULL — these are
  historical, not training-minted.
  - **Role:** matches how prod already records the old app's roles. The January 2026
    migration (`ConvertProjectUserPositionToTitle`, in #735, deleted once applied) turned that
    app's position enum (liaison/leader/assistant) into titles, and #2321 folded Leader into
    Facilitator + primary contact. Prod, profiled 2026-10-24: 1,829 Facilitators are primary
    contacts (402 aren't), all 53 Liaisons are, and 111 rows are still titled "Leader" (which
    the exact-match Facilitator scope doesn't count, and which the import matches as a
    Facilitator rather than duplicating). Of those, 109 sit beside an undated, primary
    Facilitator twin the January conversion made, and 2 have none. The Data health check
    "Affiliations still titled with an old-app role" lists every Leader, Liaison, Assistant or
    "default" row with the person's Facilitator rows at that org and links to their edit page,
    where an admin settles it by hand; nothing changes them automatically. The import matches
    any of those titles as a Facilitator.
    - Every role becomes a **Facilitator** affiliation, with a "FileMaker import" comment
      recording the role FileMaker gave. No prod row is titled Assistant, so the old app's
      assistants likely became the 402 Facilitators who aren't primary contacts.
    - Only a role FileMaker names **Leader** (8,112 of 8,907 rows) or **Liaison** (611) is
      `primary_contact`. Matching an existing Facilitator row turns its primary contact on —
      the one value the import overwrites rather than fills — and the comment says so.
    - **Assistant** (232), a blank role (80) or a stray word isn't a primary contact, and
      leaves a matched row's flag alone.
  - **One row, one stretch.** A person can facilitate at one org over several separate
    stretches (2020–2022, 2024–Oct 2025, Feb 2026–now), so a Personnel row links an existing
    Facilitator row only when their dates agree — each the same or blank on one side, and
    still start-before-end once the blanks fill. A row with no dates on either side updates
    the other (taking its dates, or the code alone). Any other dates are a separate stretch
    and come in as a new affiliation (decided 2026-10-25), leaving the portal's untouched.
  - **A row naming a project but no person** (29 of the blank-role rows) still records that
    the program ran. Once every other row is read, an organization nothing else affiliates
    anyone with gets one Facilitator affiliation for the placeholder person **AWBW
    Placeholder** (found by name, created when missing — distinct from the existing AWBW
    Staff), with a comment saying so.
  - **Dates:** Personnel rows carry none of their own, so the assignment starts on
    `DateEntered` and ends on the project's `CloseDate` (else `EndDate`). Only `Status`
    "Active" (1,774) stays open; Inactive (7,220), Pending, Suspended, blank, and values
    typed over each other ("ActiveInactive") end it now, undated (`inactive`). The run tallies
    every Status and Role value and how it was read.
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
- **Addresses are built by `FmAddressAttributes`** (ADR-0009), as the Rolodex pass does, so
  state, country, type and locality are stored as the dropdowns offer; a project's city/state
  goes through `AddressTranslation` the same way.
- **Conflicts:** a field on a record — an organization's website, mission, type — fills blanks
  and keeps the portal value where the archive disagrees, reported as a comment plus in the
  task output. A record itself comes in new instead: an affiliation whose dates differ, an
  address the organization doesn't hold, and a phone number it doesn't hold — a phone
  record (`contact_methods`) on the organization, as a person's are (decided 2026-10-25).
  Each address and phone carries its archive row's ID as its own `filemaker_code` (ADR-0005).
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
- **Which `Status` values mean active** — only "Active", from the production values profiled
  2026-10-24 (see Personnel above). A closed project's `CloseDate` (else `EndDate`) ends every
  affiliation under it. `AgreementStatus` isn't read: 8,376 of 8,907 rows leave it blank.
- **Is an Assistant a facilitator?** Yes — a Facilitator who isn't a primary contact
  (decided 2026-10-24).
- **Merged projects** (`MergerWithID`): folded — the merged-away project's code joins the
  survivor's org, so its personnel land there. One the portal already keeps as its own org
  is reported for a hand merge rather than merged automatically.
- **Unmatched people:** skipped and reported. A row naming no person at all — or only an
  agency's own Rolodex card — gets AWBW Placeholder instead, when its organization has no
  other affiliations (decided 2026-10-24).
- **Personnel with no project** (27 rows in prod, none with a project on their agreement):
  the row lands at the organization on the person's Rolodex card — its `OrgID`, else its
  typed name, created as a new organization when nothing matches. A card naming no
  organization is skipped and reported (decided 2026-10-25).
- **A full accounting of what didn't come over** — every FileMaker person and organization no
  portal record carries a code for — is a later Data health check, read through
  `filemaker_code`.
