# ADR-0011 — Importing FileMaker affiliations, one table at a time

- **Status:** Proposed
- **Date:** 2026-11-13

## TL;DR

- **Facilitator affiliations come first.** Round one reads Personnel (`fm_personnels`), and
  every row becomes a Facilitator affiliation (FA).
- **Only rows with no open question are imported.** The rest are skipped with their reason
  and listed for staff in a saved Blazer query, so nothing is guessed.
- **Round one is one task,** `fm:import_personnel` (built). It brings each row in with the dates
  FileMaker holds, and gives an Inactive row with no recorded end an inferred one, so program
  status (which reads only dates) sees it as ended.
- **Jobs come second.** Round two reads `fm_people_to_organizations` (1,128 rows in
  production). The rules below make every row a job affiliation (JA), titled or not, but
  **that's reopened** (2026-11-24): 92% of rows name someone already facilitating at that
  organization. It's settled in Open questions before round two is built.
- **Each round is its own task, shaped like `fm:import_orgs`** (#2957): `fm:import_personnel`
  (`AffiliationServices::ImportPersonnel`), then `fm:import_people_to_orgs`
  (`AffiliationServices::ImportPeopleToOrgs`). Each writes, commits in batches, skips finished
  rows on a rerun, and prints and saves a report.
- **Later rounds:** Rolodex titles and work addresses, each decided here before it's built.
- **ADR-0008's `fm:import_affiliations` is retired and deleted** (decided 2026-11-14). It did
  everything in one run; each thing it did that's still wanted becomes its own task here.

## Context

Organizations came in through `fm:import_orgs` (`OrganizationServices::ImportOrgs`, #2957),
not through ADR-0008's `fm:import_organizations`. Here is what that run left behind:

- **Every FileMaker organization's `ORG…` code is on a portal org.** It's either an org the
  run created, or an existing org that already carried one of the organization's project
  codes (`P…`).
- **One `ORG…` code can be on several portal orgs.** This happens when the organization's
  projects were already separate portal orgs (the run's "lands on more than one
  organization" list).
- **Projects weren't imported.** That's the orgs import's round two. A `P…` code is only on
  an org that already carried it before #2957.

ADR-0008's affiliations pass (`AffiliationServices::ImportFromFilemaker`, about 450 lines) does
a lot in one run:

- three source tables
- work addresses
- an AWBW Placeholder person for rows that name no one
- date-agreement rules for separate stretches
- primary-contact overrides
- reading "no longer with" notes

It also expects ADR-0008's org shape, where projects are nested orgs. That's too much to
review or undo as one run, and it doesn't fit what #2957 left. Run after `fm:import_personnel`,
it would also have placed, by guessing, exactly the rows round one sends to staff. So it's
deleted (with its specs) in the PR that adds round one, and what it did that nothing here
covers yet is listed under Later rounds.

FileMaker ties people to organizations in three places:

| Archive table | Rows | What a row is | Points at |
|---|---|---|---|
| `fm_personnels` | 8,907 | A person staffing a project: `Role`, `Status` | `PersonID` → Rolodex, `ProjectID` → `P…` |
| `fm_people_to_organizations` | 1,128 | A person's job at an organization: `Title`, `Notes` | `PersonID` → Rolodex, `OrgID` → `ORG…` |
| `fm_rolodexes` | 39,795 | A person's card, including `OrgID`/`Organization` + `Title` and work addresses | the card is the person |

Facilitator affiliations go first because they're what the portal's program status, reports
and reconciliation read (ADR-0001, ADR-0003 D1). Jobs feed none of that.

### Where FileMaker keeps facilitators

- **Personnel is FileMaker's facilitator record.** It's the child table of Projects
  (`prj_PRS__Personnel`): one row per person staffing one art program, with the `Role`
  FileMaker gave them (Leader, Liaison, Assistant; counts in ADR-0008). It hangs off a
  project, never an organization directly.
- **People-to-organizations was read as a job record** (reopened 2026-11-24, Open questions). It ties a person to an organization (`OrgID`),
  not a project, and its `Title` is free text staff typed. It has no role, status or program.
- **The two tables are separate, but name mostly the same people at the same organizations**
  (Round two's overlap profile). Neither round's rules read the other's table to decide what
  kind of affiliation a row is.
- **So a title that mentions facilitating is a job.** A people-to-organizations title like
  "Group Facilitator" is a job staff typed, not a program assignment; if the person ran a
  program, their Personnel row says so.

## Decision — round one: Personnel → Facilitator affiliations

Personnel is FileMaker's record of who ran which art program, so **every row becomes a
Facilitator affiliation**: title exactly `Facilitator`, whatever role FileMaker gave.

**Built (2026-11-14):** `AffiliationServices::ImportPersonnel` + `fm:import_personnel`.

**Import only what has no open question; send the rest to staff** (decided 2026-11-14).
Every rule below is one we're sure of. A row that hits anything we aren't sure of is skipped,
counted under its reason, and left for staff to work from a saved Blazer query run after the
import. That query lists every Personnel row no affiliation carries the code of, with the
reason and links to the FileMaker Personnel, project and organization pages, the portal
person and org, and any Facilitator affiliations the portal already has for them. Why: a
skipped row costs a staff member a few minutes later; a wrong affiliation silently changes an
org's program status and is hard to find again.

### What production holds (profiled 2026-11-13)

- **9,037 rows.** Nearly every row has `PersonID`, `DateEntered`, `ProjectID`, `Status`,
  `Name` and `Role`; 27 have no `ProjectID`, so they're skipped. `DateTimeModified` is filled on only 3,805 rows (all 2021 or later),
  `ModifiedBy` on 793 and `EnteredBy` on 534, so most rows are credited to the import user.
- **Roles:** Leader 8,112, Liaison 611, Assistant 232, blank 80, plus `Leaders` and a
  surname typed into the field (1 each). So 8,724 rows (Leader, Leaders, Liaison) make a
  primary contact and 313 don't.
- **Statuses:** Inactive 7,220, Active 1,774, blank 33, Pending 3, Suspended 1, and 6 where
  Active and Inactive were typed over each other.
- **Dates are `YYYY-MM-DD HH:MM:SS`.** `DateEntered` runs 2001-05-10 to 2026-09-23; 17 are
  blank and one reads `10/23/0209`. The project's `CloseDate` is filled on only 353
  projects (2022 onward); `EndDate` is never filled.
- **End dates are mostly missing.** Of the 7,263 rows that don't stay open (any status but
  Active, blank included), only 832 sit on a project with a `CloseDate`; **6,431 have no end
  date anywhere** in Personnel or Projects. Three Active rows sit on a closed project.
- **Person matches:** across all 9,037 rows, 8,665 find exactly one person, 370 find nobody
  and 2 find several. Of the rows naming a person code nobody carries (2026-11-17): 194 name an
  agency card (193 of them a card that names a contact), 120 name a code with no Rolodex card in
  the archive at all (102 codes), and 8 name a card missing a first or last name. Each is
  skipped under its own reason. A name-and-email match of the remaining cards to portal people
  found nothing to link: every unlinked card the rows need is one of these. Of the 8,828 rows placed at an org, 8,483
  find exactly one person; 345 find nobody or several people and are skipped.
- **What's already in the portal** for those 8,483 rows: 6,648 have nothing there, 1,823
  have a Facilitator row there (1,371 of them undated, 2 made by a training), 155 have an
  old-app title there, and 1 row's code is already on an affiliation.
- **Where every row lands** (Blazer AR2, 2026-11-17, before the notes and same-stretch rules):
  2,251 import as-is (1,379 of them links to an FA the portal holds), 5,858 import with an
  inferred end date, and 927 need a person — the largest groups two current stretches (264,
  now mostly linked by the 90-day rule), an agency card as the person (239), no org with the
  project code (106) and person not in the portal (98).
- **Separate stretches are few.** Of the person-and-org pairs, 7,789 have one Personnel row
  (1,711 Active, 6,075 not, 3 with a blank status). 336 have two rows (30 with one Active,
  306 with none) and 7 have three or more (none Active). No pair has two Active rows.

- **Person:** the `Person` whose `filemaker_code` includes the row's `PersonID` (the Rolodex
  ID that `fm:import_people` recorded).
  - Nobody carries it, or the `PersonID` is blank: the row is **skipped and listed**.
    (ADR-0008's AWBW Placeholder for person-less rows waits.)
  - Several people carry it: the row is **skipped and listed**, since they're duplicates to
    merge first.
- **Organization — the project's org:** a Personnel row names a project (`ProjectID`), not an
  organization, and #2957 didn't import projects. So it lands at **the one org carrying the
  project's `P…` code**. Anything else is **skipped and listed**: no project, a project
  missing from `fm_projects`, a code on several orgs, or a code on no org.
  - **Never the umbrella** (decided 2026-11-13). A project no org carries isn't placed at
    its FileMaker organization's org. The portal has never relied on the umbrella: of 1,527
    affiliations carrying a project code, 1,515 sit at the org with that same code, and every
    such code is on some org. If projects later come in as their own orgs, these rows can be
    placed then.
  - No matching by name. Codes only.
  - **Where production's rows land** (2026-11-13, by project):

    | Placement | Projects | Personnel rows | Active |
    |---|---|---|---|
    | One org has the `P…` code (placed) | 1,903 | 8,828 | 1,755 |
    | Only the umbrella's code is on an org (skipped) | 12 | 97 | 0 |
    | `P…` code on several orgs (skipped) | 5 | 57 | 7 |
    | Project not in `fm_projects` (skipped) | 12 | 27 | 4 |
    | Umbrella on several orgs (skipped) | 1 | 1 | 0 |

    98% of rows that name a project are placed (8,828 of 9,010), including 1,755 of the
    1,774 Active rows. The other 27 rows name no project.
  - **A project code on several orgs is an org cleanup, not an import rule** (2026-11-14:
    7 codes, 14 orgs, 57 Personnel rows). Each pair is a duplicate or a mistake: one program
    under its old and new name (40 rows), an org named "DELETE", two test orgs carrying AWBW
    Staff codes, an audience split, and two codes on an unrelated org. Staff fix the orgs (merge,
    or remove the stray code) and rerun the import, which picks the rows up. Staff can work the
    skipped rows from a saved Blazer query listing each with links to its FileMaker
    Personnel, project and organization pages, the portal person, and the umbrella org.
- **What gets created:** an `Affiliation` with
  - `title`: `Facilitator`
  - `primary_contact`: true when the role is Leader or Liaison; false otherwise (Assistant,
    blank, anything else)
  - `filemaker_code`: `PrsnlRecID`
  - `event_registration_id`: NULL
  - a comment, topic "FileMaker import", naming the role and the row's notes
- **Idempotent:** if an affiliation already carries the row's `PrsnlRecID`, the row counts as
  `already_imported`.
- **Dates:**
  - **Start:** the row's `DateEntered`, when FileMaker put them on the program.
  - **Status:** `Active` stays open, with no end date; `Inactive` is saved `inactive`.
  - **Program status reads only affiliation dates** (decided 2026-11-14), and that stays.
    `FacilitatorProgramStatus` and `AffiliationPeriods` ignore `inactive`, so an Inactive row
    with no end date would count as running to today. So every Inactive row gets one.
  - **End date of an Inactive row, first that fits** (any candidate before its start or after
    yesterday is passed over):
    1. **their own notes** (decided 2026-11-17): the latest dated entry in the Personnel row's
       `Notes` saying they stopped ("no longer", "inactive", "removed", "not active"). Notes
       read as dated entries ("1/5/2012: No longer at agency.", "no longer at program
       01/2011"); each date owns the text after it, or the text before it when nothing follows.
       A full date is used as is; a month and year means the 1st of that month, the earliest
       day we know they were gone. Entries about starting ("Now children's leader. Activated")
       are ignored, and a year alone isn't read. Notes saying the **program never started** end
       it on its start date, so the FA is zero-length and program status skips it (ADR-0001
       D8a): no program ran;
    2. the project's `CloseDate`, else its `EndDate`;
    3. their own last workshop log on that project (`fm_workshop_logs` `LeaderID` + `ProjectID`);
    4. the Personnel row's `DateTimeModified`, when staff last saved it — moved ahead of the
       workshop log when the row's own `Notes` say the person left, since that's when staff
       wrote it down (ADR-0008's pass read those notes too);
    5. the project's last workshop log, by anyone;
    6. December 31 of the year the row started, never later than yesterday (decided
       2026-11-17): a stand-in, since FileMaker says they stopped but not when, and a date is
       what keeps their history in program status. An ended program stays ended.
  - **The comment says where the end date came from,** and for the workshop logs, last-saved
    date and stand-in that FileMaker never recorded when they stopped. Notes that name other
    people stay in FileMaker; the comment quotes only the row's own notes, as before.
  - **Evidence in production** (2026-11-13, ended rows with no project `CloseDate`, each counted
    under its best source):

    | Best evidence | Rows | Range |
    |---|---|---|
    | Their own last workshop log on that project | 324 | 2019-11 to 2026-01 |
    | The project's last workshop log, by anyone | 2,094 | 2019-12 to 2026-02 |
    | Only the row's `DateTimeModified` | 570 | 2021-02 to 2026-09 |
    | Nothing (Dec 31 stand-in) | 3,443 | |

    Workshop logs only go back to late 2019 and `DateTimeModified` to early 2021, so neither
    reaches most of this history. The notes do (2026-11-17, rows that would otherwise get the
    stand-in): 1,360 have Personnel notes mentioning a year, mostly dated sign-offs like "no
    longer at program 01/2011"; 1,199 have notes with no year; 811 more have project comments
    mentioning a year; 9 have a note on the project; 38 have nothing.
  - **One task, not two** (decided 2026-11-17). The end dates were first a separate pass, to keep
    the inferred dates apart for review. Once the rule was settled, one task was simpler and
    leaves no gap where ended rows read as running; the report counts end dates by source.
- **Linking an existing affiliation:** a Facilitator affiliation (exact title) for the same
  person and org is linked when their dates agree (each the same or blank on one side, start
  still before end) and it doesn't already carry another Personnel code. It takes the code
  and fills its blank dates; a date the portal already holds stays. A Leader or Liaison turns
  its primary contact on (never off). Any other dates are a separate stretch, so the row comes
  in as a new affiliation. Rows titled with an old-app role (Leader, Liaison, …) aren't
  matched; Data health already lists them.
  - **The same stretch, dated by a training** (decided 2026-11-17): an Active row links to a
    current portal FA (no other Personnel code) starting within 90 days of FileMaker's date,
    which keeps its own dates — they come from the training — and takes the code; the comment
    notes FileMaker's date. In production 242 of the 264 rows the portal and FileMaker both
    showed as current were 2026 trainings, half within 12 days of each other and 80% within
    about 3½ weeks. Starts further apart still go to staff.
  - **Undated portal rows** (1,371 have no dates, so program status ignores them today): an
    Active Personnel row links and fills the start date — 1,302 person-and-org pairs in
    production — and from then on the org's program status counts it.
  - **When a pair has several Personnel rows** (343 pairs), they're read Active first, then
    newest `DateEntered` first, so an existing undated row takes the current stretch.
  - **Two rows that would make identical affiliations** (same dates and status, as when two
    of an org's projects were entered the same day) become one affiliation carrying both
    codes. `Affiliation#skip_if_duplicate` would otherwise refuse the second save.
- **Skipped for staff review** (each is a question this ADR doesn't answer):
  - a status other than Active or Inactive (blank 33, garbled 6, Pending 3, Suspended 1);
  - no readable start date, or one before 1990 (`10/23/0209`, likely 2009) or in the future;
  - a person code on no person or several, or a project code on no org or several;
  - an Active row on a project FileMaker closed (3), or a close date before the row was
    entered;
  - an Active row where the portal already has an open Facilitator affiliation for that
    person and org starting more than 90 days from FileMaker's date (two open stretches);
  - a row whose open/ended state disagrees with a Facilitator affiliation the portal holds
    for the same dates — including the 43 undated, open portal rows FileMaker calls
    Inactive. The portal row is left untouched; it doesn't even take the code.
- **Who and when** (the same as #2957):
  - `created_by` / `updated_by` come from `EnteredBy` / `ModifiedBy` through
    `StaffTranslation`. With no match, the import user from Settings is used.
  - `created_at` comes from `DateEntered`, and `updated_at` from `DateTimeModified`.
  - An existing row keeps its own stamps.
- **Running it** (the same as `fm:import_orgs`):
  - It writes. There's no dry run.
  - Batches of 500 rows each commit in their own transaction, so a stopped run keeps what
    it finished and a rerun picks up the rest.
  - **Activity** (decided 2026-11-17): the import runs with no `Current.source`, so its saves log
    no events of their own. It then writes one `create.affiliation` event per new affiliation,
    dated with FileMaker's `DateEntered` and credited to the staff FileMaker named (else the
    import user), so the history shows when FileMaker recorded it, not when the import ran.
    Comments, links to existing rows and org status updates log nothing, and the run logs one
    `import.affiliation` summary event with its counts and the saved report. Undo doesn't need
    events: every affiliation the import touches carries its `PS…` code and a "FileMaker
    import" comment.
  - It never runs reconciliation. That stays an admin's bulk action on an event, previewed
    row by row before anything changes.
  - The report is printed and saved as an ActiveStorage blob.
- **Report:**
  - a count for each outcome (`created`, `linked`, `merged`, `already_imported`, `skipped`,
    `failed`)
  - skipped rows counted by reason, then listed one by one with the reason
  - tallies of `Role` and `Status`
  - staff names no alias matches
- **Round one doesn't do:** the AWBW Placeholder, rows with no project (ADR-0008 used the
  person's Rolodex org), following merged projects (`MergerWithID`), addresses, or name
  matching.

## Decision — round two: people-to-organizations → job affiliations

### What production holds (profiled 2026-11-13 and 2026-11-14)

- **Every row has** `PersonID`, `OrgID`, `ModifiedBy`, `DateEntered` and
  `ModificationTimeStamp`. `Notes` is filled on 758 rows; `Title` on only 323.
- **805 rows (71%) have no title.** The table mostly records *that* someone is at an
  organization, not their job there.
- **Dates are all written `YYYY-MM-DD HH:MM:SS`.** They run from 2020-10-28 to 2026-09-25, so
  this table only covers the last six years. `DateEntered` never has a time of day.
- **Titles are almost all real job titles** (Therapist 14, Program Manager 7, Case Manager 6,
  Advocate 5, …). One row is titled `facilitator`, lowercase, and a few name facilitating
  inside a longer title ("Group Facilitator" 2, "Youth Empowerment Facilitator"). None is
  titled exactly `Facilitator`.
- **One row is titled `Liaison`,** an old-app role. It comes in as written, and the Data
  health check "Affiliations still titled with an old-app role" lists it for staff.
- **Most rows say the person left.** 757 of the 758 notes read exactly "No longer with
  organization", which the `LEFT_NOTE` wording ends; the other reads "Left in 2016", which it
  doesn't. So about two in three job affiliations from this table come in ended.
- **Matching** (profiled 2026-11-14): 845 rows find exactly one person and one org. 254 find
  one person but an `OrgID` on several orgs, 25 find no person, 3 find no org, 1 finds several
  people.
- **ORG codes on several orgs** (2026-11-14): 249 `ORG…` codes sit on 537 portal orgs; 69 of
  those codes carry 260 people-to-organizations rows. Each org holding a repeated code also
  holds its own project code, so these are a FileMaker organization's programs: #2957 put the
  organization's code on every program org it found. Only 22 of the 69 codes (67 rows) are
  audience copies of one name ("… Women's" / "… Combined"); 47 (193 rows) are differently
  named programs or sites.
- **Little is already in the portal** (2026-11-14, before the Personnel import): of the 845
  matched rows, 103 have some affiliation at that org, none with the same title, and none
  already carries the row's code.
- **Most rows name a facilitator** (profiled 2026-11-24, FileMaker's own tables, every row):

  | What else FileMaker says about the person | Rows | % | Untitled | Title mentions facilitating | Other title |
  |---|---|---|---|---|---|
  | Personnel row on a project of this same organization | 1,038 | 92.0 | 752 | 7 | 279 |
  | Personnel rows, but only at other organizations | 39 | 3.5 | 20 | 0 | 19 |
  | No Personnel row, but led a workshop log or has a facilitator-since year | 2 | 0.2 | 2 | 0 | 0 |
  | No sign of facilitating | 49 | 4.3 | 31 | 0 | 18 |

  - This shows who the rows are about, not what each row records: someone who facilitates at
    an organization can also work there.
- **The rows don't mirror Personnel** (profiled 2026-11-24; the 1,038 rows with a Personnel row
  at the same organization, against the Personnel row entered closest in time):

  | `DateEntered` apart | Rows | Untitled | Left, no Active Personnel | Left, Active Personnel | Not left, Active Personnel | Not left, no Active Personnel |
  |---|---|---|---|---|---|---|
  | Same day | 2 | 2 | 0 | 0 | 1 | 1 |
  | Within 30 days | 21 | 14 | 3 | 0 | 0 | 18 |
  | Within a year | 277 | 208 | 163 | 0 | 7 | 107 |
  | Over a year | 738 | 528 | 525 | 11 | 5 | 197 |

  - **They were entered separately:** 23 rows (2.2%) are within 30 days.
  - **They're about facilitators who stopped:** 24 rows (2.3%) have an Active Personnel row there;
    about 21% of all Personnel person-and-org pairs do.
  - **The notes don't track Personnel's status:** Personnel isn't Active for 98% of the rows that
    say the person left, and for 96% of those that don't.
  - **323 rows say nothing about leaving while Personnel isn't Active.** As Facilitator
    affiliations they'd come in open, and make ended facilitators count toward program status.
- **Few rows name the organization on the person's Rolodex card** (profiled 2026-11-24, every row):

  | The row's `OrgID` | Rows | Says they left | No left note | Untitled | Titled |
  |---|---|---|---|---|---|
  | Same as the card's | 47 | 14 | 33 | 32 | 15 |
  | Different from the card's | 239 | 148 | 91 | 145 | 94 |
  | The card has none | 842 | 596 | 246 | 628 | 214 |

  - **Where a card names an organization, 84% of rows (239 of 286) name a different one,** so the
    table reads mostly as other or earlier organizations.
  - **The 842 show less.** How many cards lack an `OrgID` in general isn't profiled.
- **Staff stamps all resolve.** Every name in `ModifiedBy` answers to a recorded staff alias,
  so no row falls back to the import user for want of one.
- **Repeats:** 16 person-and-org pairs appear more than once (33 rows); 10 of them with the
  same title (21 rows), which become one affiliation carrying every code.

### Rules

- **Person:** as in round one.
- **Organization:** the `Organization` whose `filemaker_code` includes the row's `OrgID`.
  - No org carries it: the row is **skipped** ("organization not imported").
  - Several orgs carry it (the code was spread across programs): the row is **skipped and
    listed** so staff can place it by hand. We don't guess between an umbrella's programs.
  - No matching by name. Codes only.
- **Reopened 2026-11-24:** the next two rules, on what kind of affiliation a row is, wait on
  Open questions. The rest of round two assumes them.
- **A row with no title is an untitled job affiliation** (decided 2026-11-17; 805 rows, 71% of
  the table). It still records that the person was at the organization, with the same dates
  as any row here.
- **Every row is a job affiliation** (decided 2026-11-13). Titles come in as written, so
  nothing this round makes counts toward program status or is touched by reconciliation
  (ADR-0003 D1).
  - The one `facilitator` row keeps its lowercase title. The portal's Facilitator test is an
    exact, case-sensitive match on `Facilitator`, so it stays a job affiliation.
  - A row titled exactly `Facilitator` would become a Facilitator affiliation, so it's
    skipped and listed instead. Production has none.
- **What gets created:** an `Affiliation` with
  - `title`: `Title`, squished and clipped
  - the dates FileMaker knows (below)
  - `filemaker_code`: `RecordID`
  - `event_registration_id`: NULL
- **An existing affiliation is linked, not duplicated.** If the person already has a job
  affiliation at that org with the same title (ignoring case), it gets the `RecordID` added
  to its codes, and FileMaker's dates fill any of its dates that are blank (below). A
  Facilitator affiliation is never linked, so this round never changes one.
- **Idempotent:** if an affiliation already carries the row's `RecordID`, the row counts as
  `already_imported`.
- **Dates: whatever FileMaker knows goes on the affiliation** (decided 2026-11-13). This
  table has no start or end date of its own, so the import reads its two record dates:
  - **Start:** `DateEntered`, the first day FileMaker records the person at the org. A job
    affiliation is normally undated (ADR-0003 D1) because we rarely know when it began; here
    we know at least this much.
  - **No start when the notes say they left** (decided 2026-11-17). Staff often entered the row
    and marked the person gone in one sitting, so `DateEntered` would read as a one-day job, and
    "Left in 2016" was entered in 2020 or later, after its own end. The row reads "was there,
    had left by this date".
  - **End:** only when `Notes` say the person left: "no longer with/at/works/employed" (the
    `LEFT_NOTE` wording ADR-0008 used) or "left" (decided 2026-11-14, for the one note reading
    "Left in 2016"). A note naming the year they left ends on December 31 of that year, the
    latest day it allows; otherwise the end date is the date of `ModificationTimeStamp`, the
    last time staff saved the row, when they already knew. An end date in the past makes the row
    inactive on save. With no `ModificationTimeStamp`, the row is saved `inactive` with no
    end date.
  - **The comment says when an end date is a stand-in:** FileMaker never recorded the real
    day they left, only that they had left by then.
  - **A linked existing row takes only the dates it's missing.** A date the portal already
    holds stays, since staff may have corrected it. A fill that would put the end before the
    start is skipped, and the row is listed in the report.
  - **No `LEFT_NOTE`, no end date.** The row reads as active from `DateEntered` on, because
    FileMaker says nothing more.
- **Notes:** any non-blank `Notes` become a comment on the affiliation, topic
  "FileMaker import".
- **Who and when:** as in round one, except this table has no `EnteredBy`, so both stamps
  come from `ModifiedBy`; `updated_at` comes from `ModificationTimeStamp`.
- **Running it:** as in round one, with `Current.source = "fm_import_people_to_orgs"`.
- **Report:**
  - a count for each outcome
  - the skipped and failed rows
  - the rows whose org or person code is on several records
  - linked rows whose FileMaker dates couldn't be filled (end before start)
  - a tally of titles
  - staff names no alias matches
- **Round two doesn't do:** primary contact, addresses, a placeholder person, or name
  matching.

## Later rounds (sketch; each one gets decided here before it's built)

3. **Rolodex card `OrgID` + `Title` → job affiliation.** This overlaps round two. The card
   has no ID of its own, so a rerun matches on person + org + title.
4. **Work addresses → the organization** (ADR-0008, ADR-0010).
5. **More end dates from FileMaker's other notes.** The import reads each Personnel row's own
   notes. The project's `Comments` and `MessageText` (811 stand-in rows mention a year there)
   and `fm_notes` (616 dated notes on a project, org or Rolodex card) aren't read yet; a later
   pass could move a stand-in end date to what they say, touching only affiliations whose
   comment names the stand-in.

Also in ADR-0008's pass, left out on purpose until a round decides them:

- **Agency cards are organizations, not people** (decided 2026-11-17). The organizations import
  already read them. A Personnel or job row naming an agency card as its person is skipped
  ("names an agency card, not a person") for staff; production has 158 such cards on those
  rows. No round turns an agency card's contact into a person.
- **AWBW Placeholder** — a Personnel row naming no person gave an otherwise empty org one
  Facilitator affiliation for a placeholder person, to keep the program's history.
- **Personnel rows with no project** (27) — placed at the org on the person's Rolodex card.
- **Old-app titles** — an existing Leader/Liaison/Assistant/"default" row at the org matched
  as a Facilitator. Round one matches only exact `Facilitator`; Data health lists the rest.

## Open questions

- **Round two: is a people-to-organizations row a job affiliation, a Facilitator affiliation,
  or both?** (reopened 2026-11-24; settle before building `fm:import_people_to_orgs`). 1,038 of
  1,128 rows name someone with a Personnel row at the same organization; 752 of those have no
  title.
  - **Ways a row could come in:**
    - A job affiliation, titled or not (the rules as written).
    - By title: titled rows as job affiliations; an untitled row adds its code, and its "no
      longer with" date where one is missing, to the person's Facilitator affiliation there.
    - Both: the Facilitator affiliation and the job affiliation share the row's dates.
  - **What to weigh:** a new Facilitator affiliation for each of the 1,038 would mostly
    duplicate round one's. The 90 other rows are few enough for staff to place.
  - **Leaning: job affiliations, as the rules are written.** The profile above argues against
    both a mirror of Personnel and Facilitator affiliations sharing these rows' dates.
  - **Also to settle:** 91 rows have no left note, but the person's card names a different
    organization. As written they come in as open jobs; they could come in open and be listed
    for staff.
  - **Meanwhile** the FileMaker archive shows a person's facilitator and job affiliations side
    by side, with each row's dates (#3048). That's display only: people-to-organizations rows
    sit under "Job affiliation" there, and nothing is imported by it.
- **Round two: the 260 rows whose `OrgID` is on several orgs** (decided below). A same-name merge (`fm:merge_same_named_organizations`) would settle only the
  22 audience-copy codes (67 rows). Candidate rules, strongest first: the one org carrying a
  project the person staffed (their own Personnel row); the one org where they already have an
  affiliation; the one org named "… Combined" (43 codes, 198 rows — usually the org already
  holding the affiliations). Blazer E1 counts how many rows each clue settles.
  - **What the clues settle** (production, 2026-11-14, strongest clue first):

    | Clue | Rows |
    |---|---|
    | A project the person staffed is on exactly one of the orgs | 201 |
    | They already have an affiliation at exactly one of the orgs | 1 |
    | Exactly one of the orgs is named "… Combined" | 31 |
    | Their own clues point at several of the orgs | 20 |
    | No clue | 7 |

  - **Decided 2026-11-14: place by the first clue that settles it (233 rows); send the other
    27 to staff.** The person's own clues come first. Where they say nothing, the "… Combined"
    org is close enough: for a job affiliation the exact program matters little, and it's
    usually the org already holding the affiliations. Rows whose own clues point at several
    orgs, or with no clue, go to staff.
- **Round one: reconcile vs history** (open since ADR-0008). Imported Facilitator rows have no
  registration, so the event reconcile page (which includes hand-entered rows) can end them
  when no attended training backs them. Exempt rows carrying a `PS…` code?
  - **How big it is** (production, 2026-11-13). Reconciling a training only ends an open
    Facilitator row with no training link when the person registered for a facilitator
    training linked to that org, didn't attend it, and never attended one for that org.
    - **Today:** 1,899 such rows are open. 1,776 have no training for their org, so
      reconciliation never sees them; 86 are backed by an attended training; **37 are at
      risk**, 5 of them carrying an older project code. No training has been reconciled yet.
    - **By training:** July 2026 has 12 that would end now (all no-shows), November 2026 has
      2 (cancelled). Thirteen more wait on attendance being recorded, and 14 sit on the
      On-Demand 2026 training, which hasn't ended. Eleven of those 14 were then tied to their
      On-Demand registration by a one-off console fix (2026-11-13), so reconciling that
      training treats them as rows it made; the three left are AWBW staff or older rows.
    - **After the Personnel import:** 12 more Active Personnel rows land at risk; 6 would end
      now (July 5, November 1).
  - **Leaning:** no blanket exemption. The reconcile page already previews each row and lets
    an admin keep it, and the numbers are small enough to review there. Showing an imported
    row's FileMaker code on that preview would make the choice easier.
