# ADR-0009 — Translating legacy address values into what the dropdowns store

- **Status:** Accepted
- **Date:** 2026-10-24

## Context

The portal's address country is now a dropdown (`GeographyHelper::COUNTRIES` — the
`countries` gem's names, with plain names for the formal ones), and its state field stores a
USPS code. Everything written before, and everything other systems send, is free text:

| Source | Fields |
|---|---|
| FileMaker (`fm_addresses`) | `AddrsCountry`, `AddrsState`, `AddrsType` |
| LMS registration spreadsheet (ongoing) | country, state, address type, phone type columns |
| Portal addresses and form answers from before the dropdowns | `addresses.country`/`state`; `mailing_*`/`organization_*` answers (read when an old submission is linked or captured) |

The same place arrives many ways — "US", "USA", "United States of America", "Untied States",
"California", "Ca.", "CA - California", a province typed in the state field with no country —
so one country shows up as several on dashboards, and a stored value the dropdown doesn't
list can't be preselected.

## Decision

One translator, `AddressTranslation`, used by every import and by the cleanup of existing
data. Like ADR-0007, translation is **by lookup table, and a value nothing answers to is
reported, never guessed** — it's counted in `#unmatched`. Every stored country ends up a
dropdown name or blank: a country nothing answers to is cleared (its old value stays in the
cleanup's Ahoy log, the `fm_*` archive, or the import's report). A state nothing reads is kept,
since a state is required and regions outside the US are legitimate.

- **Country** → a dropdown name. In order: a placeholder ("-", blank, "n/a", "none",
  "unknown") counts as no country; a US state code typed as the country next to that state
  is the US ("CA" beside state CA is not Canada); a spelling our data uses that the gem
  doesn't read (`ALIASES` — e.g. "Untied States", "Mexcio", "Korea" → South Korea, a US city
  or county typed as the country → US); the gem's own names and ISO codes, shown with the
  dropdown's plain names. When the country says nothing, **the state can**: a US state means
  the US, a known province or region (`REGIONS` — ON, VIC, Bucks, Ha Noi…) means its country,
  and a country typed as the state ("England", "Togo") means that country.
- **State** → the USPS code when the value reads as a US state, including a full name
  anywhere in it ("Maryland (MD)"); any other region is kept as typed. A value that reads as
  neither, on a US or country-less address, is reported.
- **Address type** → the archive's and forms' words ("Home", "cell", "Business") as the
  types we store, via one `CONTACT_TYPES` table (the Rolodex import reads phone and email
  types from it too).
- **Locality** → `AddressLocality` on the translated state and country.

### Where it runs

- **Imports, inline:** every FileMaker import builds addresses through `FmAddressAttributes`
  (the Rolodex import now, the organizations and affiliations imports of ADR-0008), and the
  LMS registration importer translates its answers. Each reports what it couldn't place.
- **Existing data, once and again:** `AddressServices::TranslateExisting`
  (`data:translate_addresses`) rewrites stored address countries and states, filling a
  locality only where it's Unknown. It's idempotent, so it runs before and after an import.
  Every changed address is an `autochange.address` Ahoy event with its before and after.
- **Where answers become addresses:** `OrganizationServices::UpsertAddress` (organization
  capture and link-organization) and `PersonServices::CaptureFromSubmission` (the mailing
  address) translate the country and state they're handed, so re-reading an old answer can't
  add a spelling the dropdowns don't offer. A submission with no country leaves the stored
  one alone.
- **Not on save.** The dropdowns own new data; nothing rewrites an address when someone
  saves a form.

### Form answers

Form answers are otherwise stored verbatim, as a record of what the person submitted, and
`data:translate_addresses` never rewrites them. They're translated where they become
addresses instead (above).

**One exception, made once by hand on 2026-10-25:** in a console pass alongside the
address cleanup, every `mailing_country` / `organization_country` answer that translates to a
dropdown country was rewritten to it ("USA", "LA County " → United States). Blank and
untranslatable answers, and every state answer, were left as typed. Each rewrite is an
`autochange.form_answer` Ahoy event (reason `answer_translation`) carrying the answer's
before value, credited to the Settings import user, with `updated_at`/`updated_by` stamped.

**Addresses in that same hand pass** carry a different trail from a `data:translate_addresses`
run: its fills — a blank country read from its state, `""` → nil, a locality filled from
Unknown — were stamped but collapsed into one `autochange.address_fills` event pointing at the
saved report (every change as CSV), while each correction of a typed value got its own event.
The rake task emits one `autochange.address` per changed address (reason
`address_translation`), fills included.

## Consequences

- A new spelling turns up in an import's or the cleanup's unmatched report; adding it is a
  line in `ALIASES` or `REGIONS`, and a re-run fills the country it had cleared (from the
  state, or by hand from the logged value).
- The `fm_*` archive tables keep FileMaker's raw values.
- Every stored country preselects in the dropdowns, so saving a form can't silently blank one.
