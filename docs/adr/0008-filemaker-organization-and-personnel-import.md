# ADR-0008 — Importing FileMaker organizations, projects and personnel

- **Status:** Proposed
- **Date:** 2026-10-17
- **Updated:** 2026-10-25

## TL;DR

Two runs after `fm:import_people` (#2630), each reversible on its own: `fm:import_organizations`
makes every organization and nothing else (`OrganizationServices::ImportFromFilemaker`), so its
count is the organization count; then `fm:import_affiliations` brings in the contact people
agency cards name and makes affiliations and work addresses
(`AffiliationServices::ImportFromFilemaker`), creating no organizations.
Row counts are production's, profiled
2026-10-12 (ADR-0005).

| Archive table | Rows | What a row is | Becomes | Code it leaves |
|---|---|---|---|---|
| `fm_organizations` | 7,240 | An umbrella organization or agency (`OrgID`, `ParentID`) | An `Organization`, parent of its programs — or, with exactly one project, the same org as that program | `ORG…` on the org |
| `fm_projects` | 2,007 | One art program run at an organization (`ProjectID`, `OrgID`) | An `Organization` (the program) nested under its organization; `Locality` and districts onto its address | `P…` on the org |
| `fm_personnels` | 9,037 | A person assigned to a project, with role and status (`PersonID`, `ProjectID`) | A Facilitator `Affiliation` at the project's org, plus a comment naming the FileMaker role | `PS…` on the affiliation |
| `fm_people_to_organizations` | 1,128 | A person's job at an organization, with title (`PersonID`, `OrgID`) | A job `Affiliation` with that title, undated unless its notes say the person left | `RecordID` on the affiliation |
| `fm_rolodexes` | 39,795 | A person's card (`OrgID`, `Organization`, `Title`, `WorksiteAddrsID`), or an agency's own card (`isAgency__c`) | A person's card: a job `Affiliation` at its organization, and its work addresses on that org. An agency's card: fills the org's website, mission, email and addresses; its contact person becomes a `Person` | None — the card's ID is the person's, from the people pass |
| `fm_addresses` | 28,556 | An address under a card (`RolodexID`), an organization (`OrgID`), or both | An `Address` on the org, always Work (Mailing/Postal becomes its invoice address); the people pass already took the personal ones | `AddrsID` on the address |
| `fm_phone_numbers` | 34,040 | A phone under a card, an organization, or both | A phone `ContactMethod` on the org | `PhoneID` on the phone |
| `fm_email_addresses` | 29 | An organization's email (`OrgID`) | The org's `email`, when blank | None |

- **Matching:** each row finds its record by `filemaker_code` first, then exact name, so a
  rerun re-reads and re-fills rather than duplicating.
- **Fields fill blanks only;** where the portal disagrees it keeps its value, noted in a
  comment and the run's report.
- **Left out:** 45 codes staff retired in FileMaker (24 fold into the organization they
  duplicated, 21 are skipped), and event registrations, payments, funding, notes and
  activities.

## Context

The Rolodex pass (`fm:import_people`, PR #2630) brings FileMaker contacts in as people:
their profile, tags, and home/mailing addresses and phones. It deliberately leaves out
everything that ties a person to an organization — job titles, facilitator assignments,
and work addresses — so they can arrive with the organizations they belong to. This is
that second pass.

The archive tables involved, and where each lands, are in the TL;DR above.

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
  (`OrganizationServices::ImportFromFilemaker`); `fm:import_affiliations` runs affiliations
  (`AffiliationServices::ImportFromFilemaker`) as its own run, so either can be checked and
  undone apart — affiliations first, since an organization someone is affiliated with is kept.
- **Organizations and projects:** an `fm_projects` row becomes (or links to) an app
  `Organization`; its `fm_organizations` row becomes (or links to) that org's parent.
  Match an existing org by any shared `filemaker_code` first, then by exact name; append
  the code on a match, as the Rolodex pass does for people.
  - **A code on a differently named org stays there, and the row gets its own org**
    (decided 2026-10-26): a code match counts only when the org answers to the FileMaker name
    of some code it carries — ignoring case, punctuation, a legal suffix, the old app's
    trailing audience word (Women's, Children's, Combined…), a namesake's "(code)", and extra
    words when one name holds every telling word of the other, and accepting a project's
    organization name for a single program. On prod's 1,522 code-carrying orgs whose name
    differs from FileMaker's, that leaves 31 for review. A merged org
    answers to one of its names, so it keeps matching every code. Otherwise the org keeps its
    code and name, and the row lands on the org its name finds or a new one, which carries the
    code too — noted as a comment on the org that had it and a line in the report. Every later
    lookup by that code (reruns, nesting, affiliations) picks the org that answers to the name.
  - **An organization with exactly one project is one org**, carrying both codes — a parent
    with a single child would be the same place twice. Only an organization with several
    projects (or none) gets its own org with the programs nested under it. When the portal
    already keeps the two apart, it stays that way.
  - **A name match only reaches an org carrying no code from the same table.** One already
    holding another project's code is a namesake; the new org is named `"Name (P1234)"`,
    since org names are unique.
  - **An organization FileMaker nests under another** (`ParentID`, 16 in prod across two
    parents) gets its parent's portal org as `parent_id`, read once every
    org is in. One the portal already nests elsewhere keeps its parent (noted), and one that lands
    on the same portal org as its parent stays as it is (decided 2026-10-25).
  - **Organization type** comes from the FileMaker organization's `OrgType`, else the
    project's `AgencyType`, first match winning: "501" or "nonprofit" → 501c3/nonprofit;
    "for-profit" or "LLC" → For-profit; "government" or "govt" → Government agency; "Other"
    → Other. Any other word ("School", "Educational Institution", "Individual", "Grassroots")
    is Other with the word as its description. A value naming two types, as FileMaker's
    multi-select stored them, takes the first.
  - **School:** a type naming "school" also sets `school`, independent of the type, since
    FileMaker kept no school flag of its own (#2866).
  - Every FileMaker organization comes over, whether or not a project or person points at it
    (decided 2026-10-24) — except one staff retired by renaming it ("DELETE", "… Do Not Use",
    "created in error"). Those are listed by code in `FilemakerValues::RETIRED_RECORDS`
    (45 of prod's 53; 3 more come in renamed, below, and the other 5 a portal org already
    carries, so they import) and skipped and reported. Most retired organizations are "X Do Not Use" duplicates whose Rolodex cards
    and jobs still point at them (76 cards in prod), so the 24 whose namesake shares a city with
    them are mapped in `RETIRED_DUPLICATE_OF` to the one they duplicated and fold into it like a
    merged project: the code, blanks, addresses, phones and projects move over and what names the
    code lands there. Where no namesake shares a city (3 in prod), it's a different organization
    and comes in as its own, "Do Not Use" dropped and its code added to the name
    (`RETIRED_RENAMED`), to dedupe later if need be. The rest are
    skipped, their projects unnested (decided 2026-10-25).
- **Agencies:** a Rolodex card flagged `isAgency__c` is the agency's own card. Its website,
  mission and addresses fill the org its `OrgID` names (or the one its `Organization` name
  matches, created when nothing does); its email too, unless the card names a contact
  person, whose email it then is. A card naming a contact person also becomes that person,
  and every address on it stays with the org. `fm:import_people` skipped every agency card,
  so `fm:import_affiliations` runs the Rolodex import over agency cards alone as its first
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
  - **"No longer with" notes:** a Personnel or people-to-organizations row whose `Notes` say
    the person is no longer with (or at, works, employed) the organization ends its
    affiliation (`inactive`) on the day the row was last saved — when staff knew they were
    gone; FileMaker never recorded the real date. A project close date still wins. The note
    becomes a comment on the affiliation, saying the actual end date isn't known.
  - An existing same-title affiliation at that org is linked (takes the code, fills blank
    dates) unless it already records another Personnel row — a second stint stays its own row.
- **People-to-organizations → job affiliation:** an `fm_people_to_organizations` row becomes
  an `Affiliation` to the org carrying its `OrgID` code with its `Title`, carrying `RecordID`
  as its code. Undated, per ADR-0003 D1, unless its notes say the person left (above).
- **The Rolodex card → job affiliation:** the card's `OrgID` (or its typed `Organization`, via
  `NameMatcher`) and `Title` become a job affiliation there — the field `FmRolodex::PORTAL_FIELDS`
  already mapped to `affiliations.title`. No code: the card's ID is the person's.
- **Work addresses:** the Rolodex `WorksiteAddrsID` address, any address typed as work (Work,
  Home/Work, Organization, Program, Corporate Office, District Office — ADR-0009's
  `CONTACT_TYPES`), and
  every address on an agency's card become an `Address` on the organization, and the
  person's affiliations there that name no address point at it
  (`affiliations.organization_address_id`), the worksite first. The organization is the one
  FileMaker filed the address under (its `OrgID`), else the card's, else the person's only
  one. A work address with no organization to land on stays with the person, typed work.
  The people pass already filed the few typed Home/Work/Organization/Program/Corporate/District
  Office on a person's card (38 in prod) on the person; this pass adds them to the organization
  too and leaves the person's copy (decided 2026-10-25), which ADR-0010's one-time move then
  removes.
- **An organization's address is always Work.** One FileMaker calls Mailing or Postal becomes
  the organization's invoice address (`invoice_address`) instead. The organization address
  form saves Work; a person's address form offers Personal (the default) or Mailing, since
  work addresses live on the organization (decided 2026-10-25).
- **Locality and districts come from the project, not derived.** `fm_projects` is the one
  place FileMaker records a `Locality`, and its vocabulary is where `Address::LOCALITIES`
  came from — so a project's `Locality`, `District`, `SPA` and `LASupervisorialDistrict`
  copy straight onto the organization's address (`locality`, `district`,
  `la_service_planning_area`, `la_supervisorial_district`). Only a person's own address has
  no locality to carry, which is why the Rolodex pass works it out with `AddressLocality`.
  Those project rows also carry real County → Locality pairs, so they are where to read
  AWBW's Northern/Central/Southern line from instead of inventing it.
  - **A project with no State but a California Locality** (LA City, LA County, Orange County,
    Northern/Central/Southern CA) is placed in CA, United States: those localities exist only
    in California (122 projects in prod, decided 2026-10-25).
  - **A project with no City** fills blanks on the organization's primary address. A
    placeholder city ("Unknown") was rejected: it would read as a real city in maps, filters
    and dedupe.
  - **One still with nowhere to land** (no City and no address on the organization, or no
    State and no California Locality) is listed in the run's report ("Projects whose place
    couldn't be saved") for staff to fix by hand.
- **Addresses are built by `FmAddressAttributes`** (ADR-0009), as the Rolodex pass does, so
  state, country, type and locality are stored as the dropdowns offer; a project's city/state
  goes through `AddressTranslation` the same way. A row with a city and state but no street
  still comes in (336 organization rows in prod), folding into an address the record already
  holds in that city (`FmAddressAttributes.held`); a row with no city or state is left out.
- **Conflicts:** a field on a record — an organization's website, mission, type — fills blanks
  and keeps the portal value where the archive disagrees, reported as a comment plus in the
  task output. A record itself comes in new instead: an affiliation whose dates differ, an
  address the organization doesn't hold, and a phone number it doesn't hold — a phone
  record (`contact_methods`) on the organization, as a person's are (decided 2026-10-25).
  Each address and phone carries its archive row's ID as its own `filemaker_code` (ADR-0005).
- **Who and when:** a new record's `created_by` / `updated_by` are the staff FileMaker named
  (`EnteredBy`/`CreatedBy`, `ModifiedBy`), resolved through `StaffAlias`
  (`data:load_staff_aliases`), else the import user picked in Settings; its `created_at` /
  `updated_at` are FileMaker's own dates. An existing record keeps its stamps. The task aborts
  with no import user or no staff aliases, and reports every staff name no alias answers to
  (#2863).
- **Running it:** dry-run by default (`DRY_RUN=false` writes). A real run commits each batch
  as it goes, so a stopped run keeps what it finished and the rerun skips it. Every record it
  creates or fills is logged under the run's name, which `fm:undo_import RUN=…` reverses.
  `FM_IDS` reads just the named archive rows — an organization always with its projects, and
  a project with its organization. The report is saved as an ActiveStorage blob.
- **Out of scope:** event registrations (`fm_participants`, 68,850 rows), payments, funding,
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
  typed name, created as a new organization when nothing matches. `fm:import_organizations`
  creates that organization, so undoing an affiliations run never removes one. A card naming
  no organization is skipped and reported (decided 2026-10-25).
- **A full accounting of what didn't come over** — every FileMaker person and organization no
  portal record carries a code for — is a later Data health check, read through
  `filemaker_code`.
