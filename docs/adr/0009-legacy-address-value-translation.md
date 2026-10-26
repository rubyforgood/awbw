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

One translator, `AddressTranslation`, used by every import. Like ADR-0007, translation is **by lookup table, and a value nothing answers to is
reported, never guessed** — it's counted in `#unmatched`. Every stored country ends up a
dropdown name or blank: a country nothing answers to is cleared (its old value stays in the
`fm_*` archive or the import's report). A state nothing reads is kept,
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
  types from it too). Its entries come from FileMaker's `AddrsType` and `PhoneType` values in
  prod (profiled 2026-10-25): FileMaker's own phone picklist "Work/Day" and "Home/Eve"
  (20,881 phones), and the address words that name a workplace (Home/Work, Organization,
  Program, Corporate Office, District Office) or post (Postal). A precedence ("Preferred",
  "Main"), a person's name, or "Fax" stays unknown, and each import's report lists the
  address and phone types nothing read. An organization's address is always work, and one
  the archive calls mailing is its invoice address (ADR-0008).
- **Locality** → `AddressLocality` on the translated state and country.

### Where it runs

- **Imports, inline:** every FileMaker import builds addresses through `FmAddressAttributes`
  (the Rolodex import now, the organizations and affiliations imports of ADR-0008), and the
  LMS registration importer translates its answers. Each reports what it couldn't place.
- **Existing data:** cleaned once by hand (below). No task rewrites stored addresses.
- **Where answers become addresses:** answers are stored on the address as submitted. Every
  form's state and country fields are dropdowns, and the older answers that could still
  become an address were fixed in the cleanup.
- **Not on save.** The dropdowns own new data; nothing rewrites an address when someone
  saves a form.

### Form answers

Form answers are stored verbatim, as a record of what the person submitted; nothing rewrites
them. The one exception is the hand cleanup below.

### Prod data cleanup, 2026-10-24 to 2026-10-25

Prod data was cleaned by hand over these two days, with addresses as the record:

- **Addresses:** cities, states, and countries corrected in the portal.
- **Blank address fields filled in** from the rest of each address: country from the state,
  county from the ZIP (FileMaker's ZIP table), and an Unknown locality from the city, county,
  and the regions FileMaker projects give each California county. Values someone set were
  kept. One `autochange.address_fills` Ahoy event points at the saved report of every fill.
- **Some form answers**, because they hadn't become addresses yet: organization address
  answers on submissions not yet linked to an organization, which turn into the
  organization's address when someone links one. Fixed: country spellings, placeholder values
  ("N/A", "-"), and values typed into the wrong field. Each change is an
  `autochange.form_answer` Ahoy event with its before value.

All other answers stay as typed.

## Consequences

- A new spelling turns up in an import's unmatched report; adding it is a line in `ALIASES`
  or `REGIONS`.
- The `fm_*` archive tables keep FileMaker's raw values.
- Every stored country preselects in the dropdowns, so saving a form can't silently blank one.
