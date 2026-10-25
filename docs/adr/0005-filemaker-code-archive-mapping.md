# ADR-0005 — Which FileMaker archive table each `filemaker_code` points at

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

FileMaker is the legacy system we import from (rubyforgood/awbw#508). It isn't the
source of truth across the board: staff edited records in both FileMaker and the
portal, so for some data the portal is right and for some FileMaker is. The raw
export lives in the read-only `fm_*` archive tables (one per FileMaker table, keyed
by `fm_id`, every other field in a `data` JSON column; see `lib/tasks/fm_import.rake`).
Eight app tables carry a `filemaker_code` column, read as a comma-separated set of
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
| `affiliations.filemaker_code` | `fm_projects`, then `fm_personnels`, then `fm_people_to_organizations` | `ProjectID`, e.g. `P2775`; `PrsnlRecID`, e.g. `PS9999`, and `RecordID`, e.g. `112`, from the ADR-0008 import | `filemaker_code_links` on affiliation edit |
| `payments.filemaker_code` | `fm_payments` | `RecordID`, e.g. `D29186` | `filemaker_code_hint` on payment edit |
| `workshops.filemaker_code` | `fm_workshops` | `WorkshopID` | `filemaker_code_hint` on workshop form |
| `resources.filemaker_code` | none | `RecordID` of the source quotation, e.g. `Q10215` | resource form (editable, no archive link) |
| `addresses.filemaker_code` | `fm_addresses` | `AddrsID`, e.g. `1234` | `fm_archives#show` links back to the address's person or org |
| `contact_methods.filemaker_code` | `fm_phone_numbers` | `PhoneID`, e.g. `5678` | `fm_archives#show` links back to the phone's person |

- **Organization → Project, or → Organization.** An app `Organization` is usually one
  art program site, which is a FileMaker *Project*. FileMaker's own Organization row is
  the umbrella above it, and maps to the parent in the nested-org tree (ADR-0004); an
  app org can carry that `ORG…` code directly too. Links run both ways through
  `Project.OrgID`: the org edit page links the FM organization each of its projects
  sits under, and an FM organization's archive page lists the orgs carrying its code
  or one of its projects' codes.
- **Codes match in full, never by number alone.** `P00023` and `ORG00023` are different
  records, and a bare `00023` matches neither. The prefix is part of the id, and
  prefixes aren't unique to one table (see below), so nothing strips or routes by it.
- **Affiliation → Project.** Production affiliations carry their org's project id,
  not a Personnel id. Of 1,531 `P` + 4-digit codes, all 1,531 are real projects and
  1,518 equal the affiliation's own org code. Reading them as Personnel ids missing the
  `S` matched the affiliation's person once and its org never; as participant ids,
  never its org. One affiliation carries a real `PS` Personnel id, so Personnel stays
  as the second table. The 13 that differ from the org's code are worth a look: the
  affiliation may sit on the wrong org, or the org may be missing that code.
- **Resource → none.** In production, 116 of 128 resource codes are quotation ids
  (`Q…`), 115 of them on Leader spotlight resources and one on a Story: each spotlight's
  body is the text of the FileMaker quotation it was built from. A resource is still its
  own portal record, not an archive row, and quotations belong with the portal's quotes,
  so resource codes stay editable but don't link into the archive or back. The dev seed
  leaves `resources.filemaker_code` blank.

## Archive id patterns

What each archive table's `fm_id` looks like in production, profiled 2026-10-12 with a
digits-as-`9` shape query over every archive table. Every table came back with a
single prefix and fixed-width digits unless noted. Re-run it and update this grid
when a new export lands.

| Archive table | FileMaker key | Id pattern | Range in prod | Rows | Portal column |
|---|---|---|---|---|---|
| `fm_activities` | `ActivityLogID` | 5 digits | `00011`–`30061` | 29,185 |  |
| `fm_addresses` | `AddrsID` | 1–5 digits, unpadded | `1`–`30808` | 28,556 | `addresses` |
| `fm_allocations` | `AllocRecID` | 4 digits | `0001`–`3508` | 3,098 |  |
| `fm_ancillary_data` | `RecordID` | 1–3 digits, unpadded | `1`–`559` | 556 |  |
| `fm_art_purchases` | `PurchaseID` | 4 digits | `0001`–`0226` | 226 |  |
| `fm_art_registries` | `ItemID` | `A` + 4 digits | `A0001`–`A4405` | 3,902 |  |
| `fm_campaigns` | `CampaignID` | `CMP` + 3 digits | `CMP002`–`CMP011` | 10 |  |
| `fm_committee_meetings` | `CtMtgID` | `CMT` + 4 digits | `CMT0001` | 1 |  |
| `fm_committee_members` | `CMRecID` | `CM` + 4 digits | `CM0001`–`CM0741` | 689 |  |
| `fm_committees` | `CommitteeID` | `CT` + 3 digits | `CT001`–`CT060` | 28 |  |
| `fm_contacts` | `ContactID` | 5 digits | `00030`–`35548` | 248 |  |
| `fm_donor_developers` | `DonorDevRecID` | `SLR` + 4 digits | `SLR0001`–`SLR0172` | 164 |  |
| `fm_email_addresses` | `EmailAddrsID` | 1–2 digits, unpadded | `1`–`29` | 29 |  |
| `fm_events` | `EventID` | `E` + 4 digits | `E0002`–`E4048` | 3,478 |  |
| `fm_exhibited_items` | `RecordID` | `X` + 5 digits | `X00002`–`X03154` | 2,693 |  |
| `fm_expenditures` | `ExpendRecID` | `X` + 4 digits | `X0001`–`X5510` | 5,314 |  |
| `fm_form_fields` | `FieldNo` | 1–3 digits, optional `.` + 1–2 digits | `1.3`–`125.4` | 318 |  |
| `fm_form_letters` | `DocID` | `D` + 3 digits | `D064`–`D658` | 272 |  |
| `fm_form_submissions` | `RecordID` | `FSB` + 5 digits | `FSB00001`–`FSB03265` | 3,265 |  |
| `fm_forms_lists` | `FormID` | 2–3 digits, unpadded | `48`–`307` | 9 |  |
| `fm_fundings` | `RecordID` | `F` + 4 digits | `F0004`–`F1581` | 1,391 |  |
| `fm_group_members` | `RecordID` | `GM` + 5 digits | `GM00001`–`GM00017` | 16 |  |
| `fm_groups` | `GroupID` | `GP` + 5 digits | `GP00004`–`GP00273` | 245 |  |
| `fm_invoices` | `RecordID` | `INV` + 5 digits | `INV00003`–`INV02247` | 2,064 |  |
| `fm_line_items` | `ItemID` | `LIT` + 5 digits | `LIT01001`–`LIT01103` | 103 |  |
| `fm_match_donations` | `RecordID` | `MDN` + 4 digits | `MDN0001`–`MDN3454` | 3,250 |  |
| `fm_notes` | `NoteID` | `N` + 5 digits | `N00007`–`N00643` | 616 |  |
| `fm_organizations` | `OrgID` | `ORG` + 5 digits | `ORG00001`–`ORG07256` | 7,240 | `organizations` |
| `fm_participants` | `PRecID` | `P` + 4–5 digits | `P0001`–`P79284` | 68,850 |  |
| `fm_payments` | `RecordID` | `D` + 5 digits | `D00001`–`D29263` | 27,220 | `payments` |
| `fm_people_to_organizations` | `RecordID` | 1–4 digits, unpadded | `1`–`1128` | 1,128 |  |
| `fm_personnels` | `PrsnlRecID` | `PS` + 4–5 digits | `PS0028`–`PS10667` | 9,037 | `affiliations` |
| `fm_phone_numbers` | `PhoneID` | 2–5 digits, unpadded | `22`–`35946` | 34,040 | `contact_methods` |
| `fm_postal_codes` | `Zipcode` | 5-digit ZIP | `00501`–`99950` | 41,685 |  |
| `fm_program_sponsorships` | `RecordID` | `PSP` + 4 digits | `PSP0035`–`PSP0901` | 608 |  |
| `fm_projects` | `ProjectID` | `P` + 4 digits | `P0001`–`P2806` | 2,007 | `organizations` |
| `fm_quotations` | `RecordID` | `Q` + 4–5 digits | `Q0880`–`Q65300` | 62,611 |  |
| `fm_reportings` | `ReportID` | 5 digits | `00001`–`00791` | 727 |  |
| `fm_rolodexes` | `ID` | 5 digits, zero-padded | `00006`–`43871` | 39,795 | `people` |
| `fm_services` | `RecordID` | 5 digits | `00001`–`73063` | 69,590 |  |
| `fm_solicitations` | `SolicitationID` | `SLN` + 5 digits | `SLN00001`–`SLN12043` | 11,815 |  |
| `fm_volunteers` | `VolID` | 5 digits | `00001`–`37788` | 2,845 |  |
| `fm_workshop_logs` | `RecordID` | 5 digits | `45920`–`56833` | 10,859 |  |
| `fm_workshops` | `WorkshopID` | `W` + 4 digits | `W0002`–`W0830` | 713 | `workshops` |

### Where ids collide across tables

The same string can be a valid id in more than one table, so a code is only ever
looked up, in full, in the tables its portal column declares — never routed by prefix
or shape.

- **`P` + 4 digits is both a project and a participant.** Projects run `P0001`–`P2806`;
  participants run `P0001`–`P79284`, so every project id is also a participant id.
- **`X`:** exhibited items are `X` + 5 digits, expenditures `X` + 4 digits.
- **`D`:** form letters are `D` + 3 digits, payments `D` + 5 digits.
- **Nested prefixes:** `P` / `PS` / `PSP`, `CM` / `CMP` / `CMT`, and `SLR` / `SLN`.
- **Bare 5-digit numbers** are Rolodex ids and also activities, contacts, services,
  volunteers, reportings, workshop logs, and ZIP codes, with overlapping ranges.
- **Unpadded numbers** (addresses, phones, ancillary data, people-to-organizations,
  email addresses, forms lists) overlap each other from `1` up.

## What portal records store

Shapes of the codes on portal records in production, profiled 2026-10-12 (comma lists
split into single codes). Compare against the grid above.

| Portal column | Codes | Matches its mapping | Outliers |
|---|---|---|---|
| `organizations` | 1,987 | 1,965 `P` + 4 digits (projects) | 22: unpadded `P622`; no prefix `627`, `628`, `2781`, `9530`; letter O for zero `PO296`; extra digit `P03484`; `PP256`; placeholder `F0000` ×2; bare 5-digit numbers ×9 (Rolodex-shaped); 2 unreadable values |
| `people` | 1 | 1 Rolodex-shaped (`39853`) | — the column is effectively unused |
| `affiliations` | 1,535 | 1,531 `P` + 4 digits (projects; 1,518 equal the org's code), 1 `PS` (personnel) | `ORG05589`, `PP208`, `09856` |
| `payments` | 0 | — | — |
| `workshops` | 850 | 849 `W` + 4 digits | `XVI/4` |
| `resources` | 128 | 115 `Q` + 4–5 digits found in quotations (114 Leader spotlight, 1 Story) | 1 `Q` id not in the archive; 10 bare 2–3 digit numbers, `v`, and a URL, all on Leader spotlights |

Outliers get fixed by hand, not backfilled. Those codes already show struck through
in the code field's hint.

### Records to fix by hand

Ids only, by issue. Nothing here names a record or repeats its code; open the record by
id to see the code. Look the right id up in the archive, then fix the record's
FileMaker code field.

| Issue | Fix |
|---|---|
| Well-formed code with no archive record | Likely a digit typo. Find the record in the archive by name and replace the code, or clear it if FileMaker has no such record. |
| Number without its prefix, or the wrong kind of id | Add the missing prefix and padding (e.g. `P` + 4 digits for a project), or, if it's another table's id (a 5-digit Rolodex id on an org), move it to the right record and clear it here. |
| Malformed code | Fix the letters (a letter `O` for a zero, a doubled prefix), drop extra digits, or clear placeholders and pasted text. An `ORG…` code on an affiliation belongs on its org instead. |
| Unreadable value | The stored value has characters that can't be split into codes. Retype the code. |
| Project code differs from its org's code (affiliations) | Either the affiliation is on the wrong org (move it), or the org is missing that project code (add it to the org). |

Production, 2026-10-12: 84 records (41 organizations, 16 affiliations, 14 workshops,
13 resources, no people). A record listed under two issues has two bad codes.

| Portal table | Issue | Count | Record ids |
|---|---|---|---|
| `organizations` | Well-formed code with no archive record | 19 | 66, 247, 270, 283, 297, 365, 425, 437, 443, 499, 665, 668, 670, 814, 973, 1046, 1091, 1107, 1398 |
| `organizations` | Number without its prefix, or the wrong kind of id | 14 | 233, 364, 388, 439, 593, 614, 640, 641, 822, 838, 865, 877, 978, 2043 |
| `organizations` | Malformed code | 8 | 108, 136, 241, 941, 1088, 1089, 1550, 1891 |
| `affiliations` | Number without its prefix, or the wrong kind of id | 1 | 4424 |
| `affiliations` | Malformed code | 2 | 5236, 6385 |
| `affiliations` | Project code differs from its org's code | 13 | 2656, 3649, 3730, 5042, 5043, 5164, 5461, 5857, 5920, 6178, 6234, 6284, 6387 |
| `workshops` | Well-formed code with no archive record | 13 | 215, 294, 357, 501, 708, 756, 797, 865, 926, 954, 982, 1010, 6302 |
| `workshops` | Malformed code | 1 | 521 |
| `resources` | Well-formed code with no archive record | 1 | 624 |
| `resources` | Number without its prefix, or the wrong kind of id | 10 | 572, 573, 574, 575, 588, 592, 593, 594, 595, 596 |
| `resources` | Malformed code | 2 | 550, 580 |

## Consequences

A UI link for a new FileMaker-coded column includes `FilemakerCoded` on the
model and declares the archive table above (e.g. `filemaker_archived_in FmPersonnel`);
`filemaker_code_links` reads it from there.
