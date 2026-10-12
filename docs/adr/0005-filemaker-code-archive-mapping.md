# ADR-0005 — Which FileMaker archive table each `filemaker_code` points at

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

FileMaker is the source of truth we import from (rubyforgood/awbw#508). The raw
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

| App column | Archive table | Archive key | Where it's relied on |
|---|---|---|---|
| `people.filemaker_code` | `fm_rolodexes` | `ID`, e.g. `00006` | `filemaker_code_links` on person edit + admin details |
| `organizations.filemaker_code` | `fm_projects` | `ProjectID`, e.g. `P2775` | `filemaker_code_links` on org edit + form |
| `affiliations.filemaker_code` | `fm_personnels` | `PrsnlRecID`, e.g. `PS9999` | dev seed only |
| `payments.filemaker_code` | `fm_payments` | `RecordID`, e.g. `D29186` | dev seed only |
| `workshops.filemaker_code` | `fm_workshops` | `WorkshopID` | dev seed only |
| `resources.filemaker_code` | none | — | unmapped |

- **Organization → Project, not → Organization.** An app `Organization` is one art
  program site, which is a FileMaker *Project*. FileMaker's own Organization row is
  the umbrella above it, and maps to the parent in the nested-org tree (ADR-0004).
- **Affiliation → Personnel.** Personnel is a person on a project with a role and
  agreement status. With orgs = projects, that's an affiliation.
- **Resource has no counterpart.** No archive table holds resources. Form Letters
  are mail-merge templates, not resources, and nothing in the app maps to them. The
  seed leaves `resources.filemaker_code` blank.

## Consequences

The "dev seed only" rows are the seed's working assumption. Confirm them (and the
`fm_*` table to pass) before adding a `filemaker_code_links` call for affiliations,
payments, or workshops.
