# ADR-0005 — Which FileMaker archive table each `filemaker_code` points at

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

FileMaker is the legacy system we import from (rubyforgood/awbw#508). It isn't the
source of truth across the board: staff edited records in both FileMaker and the
portal, so for some data the portal is right and for some FileMaker is. The raw
export lives in the read-only `fm_*` archive tables (one per FileMaker table, keyed
by `fm_id`, every other field in a `data` JSON column; see `lib/tasks/fm_import.rake`).
Six app tables carry a `filemaker_code` column, read as a comma-separated set of
codes (`FilemakerCoded`). The code is an archive `fm_id`, but nothing recorded *which*
archive table each column's codes belong to. The dev seed (`db/seeds/dev/fm_archive.rb`)
had to choose, so this records the choice.

Relationships *between* archive tables are not covered here. Each `app/models/fm_*.rb`
documents its own fields and FKs in its header comment, and `FM_LINKS` / `HAS_MANY`
drive the archive pages' links.

## Decision

| App column | Archive table | Archive key | Read by |
|---|---|---|---|
| `people.filemaker_code` | `fm_rolodexes` | `ID`, e.g. `00006` | `filemaker_code_links` on person edit + admin details |
| `organizations.filemaker_code` | `fm_projects`, then `fm_organizations` | `ProjectID`, e.g. `P2775`; `OrgID`, e.g. `ORG07206` | `filemaker_code_links` on org form; `filemaker_project_links` / `filemaker_organization_links` on org edit |
| `affiliations.filemaker_code` | `fm_personnels` | `PrsnlRecID`, e.g. `PS9999` | dev seed (no UI link yet) |
| `payments.filemaker_code` | `fm_payments` | `RecordID`, e.g. `D29186` | dev seed (no UI link yet) |
| `workshops.filemaker_code` | `fm_workshops` | `WorkshopID` | dev seed (no UI link yet) |
| `resources.filemaker_code` | none | — | unmapped |

- **Organization → Project, or → Organization.** An app `Organization` is usually one
  art program site, which is a FileMaker *Project*. FileMaker's own Organization row is
  the umbrella above it, and maps to the parent in the nested-org tree (ADR-0004); an
  app org can carry that `ORG…` code directly too. The org edit page also links the
  FM organization each of its projects sits under (`Project.OrgID`).
- **Codes match in full, never by number alone.** `P00023` and `ORG00023` are different
  records, and a bare `00023` matches neither. The prefix is part of the id, and
  prefixes aren't unique to one table (see below), so nothing strips or routes by it.
- **Affiliation → Personnel.** Personnel is a person on a project with a role and
  agreement status. With orgs = projects, that's an affiliation.
- **Resource has no counterpart.** No archive table holds resources. Form Letters
  are mail-merge templates, not resources, and nothing in the app maps to them. The
  seed leaves `resources.filemaker_code` blank.

## Archive id patterns

What each archive table's `fm_id` looks like, as far as we know. Add to it as we
learn more from the export. Evidence is each `app/models/fm_*.rb` header (PK and FK
examples); "?" means we haven't seen one yet.

| Archive table | FileMaker key | Id pattern | Example | Portal column |
|---|---|---|---|---|
| `fm_activities` | `ActivityLogID` | ? | | |
| `fm_addresses` | `AddrsID` | ? | | |
| `fm_allocations` | `AllocRecID` | ? | | |
| `fm_ancillary_data` | `RecordID` | ? | | |
| `fm_art_purchases` | `PurchaseID` | ? | | |
| `fm_art_registries` | `ItemID` | ? | | |
| `fm_campaigns` | `CampaignID` | ? | | |
| `fm_committee_meetings` | `CtMtgID` | ? | | |
| `fm_committee_members` | `CMRecID` | ? | | |
| `fm_committees` | `CommitteeID` | ? | | |
| `fm_contacts` | `ContactID` | ? | | |
| `fm_donor_developers` | `DonorDevRecID` | ? | | |
| `fm_email_addresses` | `EmailAddrsID` | ? | | |
| `fm_events` | `EventID` | `E` + digits | `E4037` | |
| `fm_exhibited_items` | `RecordID` | ? | | |
| `fm_expenditures` | `ExpendRecID` | `X` + digits | `X5510` | |
| `fm_form_fields` | `FieldNo` | ? | | |
| `fm_form_letters` | `DocID` | ? | | |
| `fm_form_submissions` | `RecordID` | likely `FSB` + 5 digits (seen only as refs from payments/personnel) | `FSB03117` | |
| `fm_forms_lists` | `FormID` | ? | | |
| `fm_fundings` | `RecordID` | `F` + digits | `F1581` | |
| `fm_group_members` | `RecordID` | ? | | |
| `fm_groups` | `GroupID` | ? | | |
| `fm_invoices` | `RecordID` | ? | | |
| `fm_line_items` | `ItemID` | ? | | |
| `fm_match_donations` | `RecordID` | ? | | |
| `fm_notes` | `NoteID` | `N` + 5 digits | `N00643` | |
| `fm_organizations` | `OrgID` | `ORG` + 5 digits | `ORG07206` | `organizations` |
| `fm_participants` | `PRecID` | `P` + digits (same prefix as projects) | `P52646` | |
| `fm_payments` | `RecordID` | `D` + digits | `D29186` | `payments` |
| `fm_people_to_organizations` | `RecordID` | ? | | |
| `fm_personnels` | `PrsnlRecID` | `PS` + digits | `PS9999`, `PS10005` | `affiliations` |
| `fm_phone_numbers` | `PhoneID` | ? | | |
| `fm_postal_codes` | `Zipcode` | the ZIP code | | |
| `fm_program_sponsorships` | `RecordID` | `PSP` + 4 digits | `PSP0901` | |
| `fm_projects` | `ProjectID` | `P` + digits | `P2775` | `organizations` |
| `fm_quotations` | `RecordID` | ? | | |
| `fm_reportings` | `ReportID` | ? | | |
| `fm_rolodexes` | `ID` | digits only, zero-padded to 5 (`6` ≠ `00006`) | `00006` | `people` |
| `fm_services` | `RecordID` | ? | | |
| `fm_solicitations` | `SolicitationID` | ? | | |
| `fm_volunteers` | `VolID` | ? | | |
| `fm_workshop_logs` | `RecordID` | ? | | |
| `fm_workshops` | `WorkshopID` | `W` + 4 digits | `W0421` | `workshops` |

Prefixes overlap: `P` is both projects and participants, and `P` / `PS` / `PSP` nest.
That's why a code is only ever looked up, in full, in the tables its portal column
declares.

## Consequences

A UI link for affiliations, payments, or workshops includes `FilemakerCoded` on the
model and declares the archive table above (e.g. `filemaker_archived_in FmPersonnel`);
`filemaker_code_links` reads it from there.
