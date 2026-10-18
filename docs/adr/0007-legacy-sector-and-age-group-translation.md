# ADR-0007 — Translating legacy sector and age-group words into the portal's tags

- **Status:** Accepted
- **Date:** 2026-10-14

## Context

Four systems asked people who they serve, each with its own word list:

| Source | Fields |
|---|---|
| FileMaker (`fm_rolodexes`) | `PrimaryServiceArea`, `OtherServiceArea`, `Settings`, `LifeExperiences`, `PrimaryAgeGroup` |
| Collab / training registration / scholarship forms | the same four, with longer prose labels |
| Story Share | Categories, Windows Audience, Age Range |
| The portal, before the 2026 consolidation | its own earlier sector names |

The portal now carries one canonical vocabulary — `Sector::SECTOR_TYPES`, the `AgeRange`
categories (Children, Teens, Adults, Elders), and the `StoryPopulation` categories (Self,
Colleagues, Community, Families). The renames, merges and additions that produced it are
already done; `db/seeds.rb` reconciles all three lists.

What was never written down is how a *legacy input* becomes one of those tags. Every
importer and backfill has to answer that per value — `PersonServices::ImportFromRolodex`
first — and each would otherwise invent its own guesswork. This records the answer.

## Decision

Translation is by lookup table, not by string similarity. A value that isn't in a table is
**reported, never guessed**.

### Reading a source value

- Compare case-insensitively, ignoring surrounding whitespace. Most of the archive's
  long tail is case variants ("Domestic violence" alongside "Domestic Violence"), so this
  alone collapses it.
- One field may list several areas: split on **line breaks and semicolons**, then translate
  each piece. **Not on commas** — the wording itself contains them, inside parentheticals
  like "Community violence (gang violence, mass shootings, police violence, etc.)".
- Drop a trailing parenthetical when the term alone resolves, so the forms' clarifying
  tails ("Grief/loss (including COVID-related)") need no separate entry.
- Many source values mapping to one tag is normal. Only `C & T` maps to two tags.
- The portal spelling wins where the spreadsheet differs: **`Systems/Policy Change`** (the
  sheet's "Sytems" is a typo, recorded as an alias so it still resolves).
- `Other` is a form-only catch-all. It is never a translation target.

### FileMaker `PrimaryServiceArea` → sector

| FileMaker | Sector |
|---|---|
| Community Oppression/Violence | Community Violence |
| Criminal/Legal | Court/Legal System |
| Disability Services | Disability Services |
| Domestic Violence | Domestic Violence |
| Foster Care | Foster Care/Adoption |
| Homelessness | Homelessness |
| Human Trafficking | Human Trafficking |
| Immigration | Immigration |
| Incarceration | Incarceration |
| Indigenous/Tribal Nation | Indigenous/Tribal Nation |
| LGBTQIA+ | LGBTQIA+ |
| Mental Health | Mental Health |
| Reproductive Services | Reproductive Services |
| Restorative/Transformative Justice | Restorative/Transformative Justice |
| Sexual Assault | Sexual Assault |
| Student Services | Education |
| Substance Abuse | Substance Use/Recovery |

### FileMaker `Settings` → sector

| FileMaker | Sector |
|---|---|
| Clinical Setting | Mental Health |
| Educational Setting | Education |
| Faith-Based Setting | Religious/Faith-Based |
| Hospitals | Health/Medical |
| Law Enforcement/Court | Court/Legal System |
| Prisons/Jails | Incarceration |
| Private Practice | Private Practice/Sole Proprietor |
| With Staff | Staff/Organizational Development |

**Dropped, not mapped:** Community-Based, Events and Conferences, Home Visits, Outreach
Program, Residential Program, Virtually. These say *where or how* a facilitator works, not
who they serve — they aren't sectors and have no portal home.

### FileMaker `LifeExperiences` → sector

| FileMaker | Sector |
|---|---|
| Child Abuse/Neglect | Child Abuse/Neglect |
| Climate/Environmental Trauma | Climate/Environmental |
| Community Violence | Community Violence |
| Domestic Violence | Domestic Violence |
| Foster Care | Foster Care/Adoption |
| Grief/Loss | Grief/Loss |
| Homelessness | Homelessness |
| Human Trafficking | Human Trafficking |
| Illness | Health/Medical |
| Immigration | Immigration |
| Incarceration | Incarceration |
| Mental Health Needs | Mental Health |
| Military/Veteran | Military/Veterans |
| Oppression Against LGBTQIA+ | LGBTQIA+ |
| Pandemic-Related Stress | Health/Medical |
| People Who Do Harm/Batterers | Batterers Intervention |
| Racism and Marginalization (the sheet writes it "Racism & Marginalization"; both resolve) | Racial/Social Justice |
| Religious Trauma | Religious/Faith-Based |
| Restorative/Transformative Justice | Restorative/Transformative Justice |
| Secondary/Vicarious Trauma | Staff/Organizational Development |
| Sexual Assault | Sexual Assault |
| Student-Related Stress | Education |
| Substance Abuse | Substance Use/Recovery |
| Suicidality | Mental Health |
| Victims of Crime | Court/Legal System |

**No sector yet:** Elder Abuse, People Who Have Experienced War, Poverty. Left unmapped on
purpose — each needs a sector added before it can be translated, and inventing a near-miss
would bury the gap. An importer reports them.

### Cells naming more than one sector

Hand-typed answers that name several sectors resolve to all of them — the same one-to-many
shape as `C & T`. Recorded only where every concept in the cell is itself a decided term:
`Domestic Violence & Homelessness` · `Sexual Assault & Domestic Violence` ·
`Domestic Violence, Sexual Assault` · `Domestic Violence and Sexual Assault survivors` ·
`Domestic and Sexual Violence Families` · `Sexual and Domestic Violence Agency` ·
`DV/SA/other related crimes` · `Dual Agency Domestic violence/Sexual assault/ Human
trafficking` · `Immigration, Health, Prevention of Violence and Education` ·
`Addiction, Native Americans, mental health and addiction` · `Education, SEL needs` ·
`Hospice, end of life, bereavement`.

### Terms that cross vocabularies

Two of the archive's *sector* fields carry terms that say which **ages** someone serves, so
they resolve to an age range rather than a sector:

| Source value | Portal tag |
|---|---|
| `Elder Abuse` (LifeExperiences) | AgeRange **Elders** |
| `Children's Services` (PrimaryServiceArea) | AgeRange **Children** |

Whether the tag lands as the **primary** or an **additional** one follows from the field the
term sat in, not from the term: `PrimaryServiceArea` and `PrimaryAgeGroup` are the primary
answers, `OtherServiceArea`, `Settings` and `LifeExperiences` the additional ones. So
`Children's Services` makes Children the primary age range, and `Elder Abuse` adds Elders
alongside whatever the primary already is.

### Reads of the free text, pending staff validation

The archive's hand-typed cells are mostly a venue, a programme name or a sentence about the
work. Where the meaning is plain — `Immigration Clinic`, `Grief support group`,
`Inpatient Psychiatric Hopital`, `Supervised visitation sessions for foster youth…` — the
term is recorded as **proposed**: it resolves, so an import doesn't lose it, and
`TagAlias.proposed` is the list to walk with staff term by term. About 90 terms, each worth
one or two archive rows.

**What is deliberately not read:** anything naming an organization, a place that identifies
one, or a facilitator's own circumstances. That text is personal and belongs in the archive,
not copied into a catalogue — which leaves 23 terms, 23 mentions, unresolved for good.

### Answers that name nothing

Alongside the dropped Settings, these are recorded as naming nothing on purpose: `Other` ·
`Did not specify` · `n/a` · `none` · `something` · `unsure` · `Everyone` · `Technology` ·
and the delivery modes `In person` · `In visits` · `virtually & in-person` · `At office` ·
`Office space.` · `Residential` · `On-Call/Crisis` · `Support groups`. None of them says
who a facilitator serves, so leaving them in the undecided queue would only bury the terms
that do.

**`People Who Have Experienced War` (97) joins them by decision, not by shape.** It names a
real experience, and Community Violence was the fallback if it had to go somewhere — but
AWBW chose to leave it untagged rather than file it under a sector it doesn't mean.

### Story Share categories → sector

| Story Share | Sector |
|---|---|
| Advocacy | Systems/Policy Change |
| Batterers Intervention | Batterers Intervention |
| Child Abuse / Neglect | Child Abuse/Neglect |
| Community Engagement | Community Building |
| Community Violence | Community Violence |
| Court & Legal System | Court/Legal System |
| Disability Services | Disability Services |
| Domestic Violence | Domestic Violence |
| Donor Engagement | Fundraising/Donor Engagement |
| Foster Care | Foster Care/Adoption |
| Grief & Loss | Grief/Loss |
| Homelessness | Homelessness |
| Human Trafficking | Human Trafficking |
| Immigration | Immigration |
| Incarceration | Incarceration |
| LGBTQIA+ | LGBTQIA+ |
| Mental Health | Mental Health |
| Military & Veterans | Military/Veterans |
| Physical & Terminal Illness | Health/Medical |
| Schools & Universities | Education |
| Self-Care & Personal Growth | Self-Care/Personal Growth |
| Sexual Assault | Sexual Assault |
| Social Justice | Racial/Social Justice |
| Staff & Organizational Development | Staff/Organizational Development |
| Substance Abuse Recovery | Substance Use/Recovery |

**Not a sector:** Facilitator Spotlights. It describes the story, not who it serves.

### Earlier portal sector names → sector

Already applied in the portal by rename and merge, recorded so an old export still reads:
Child abuse → Child Abuse/Neglect · Community oppression/violence → Community Violence ·
Criminal/legal → Court/Legal System · Disability (and Disabled, Disabled Person) →
Disability Services · Education/schools and Student → Education · Family Violence and
Children of Domestic Violence Survivors → Domestic Violence · Foster care/adoption (and
Foster Youth, Foster children/APPS) → Foster Care/Adoption · Grief and loss → Grief/Loss ·
Lgbtqia+ → LGBTQIA+ · Mental illness → Mental Health · Reproductive → Reproductive
Services · Serious illness → Health/Medical · Staff & organizational development →
Staff/Organizational Development · Substance use → Substance Use/Recovery · Veterans &
military → Military/Veterans.

### Age groups

| Source value | Portal tag |
|---|---|
| FileMaker `Children`; Story Share `3-5`, `6-12`, `Children` | AgeRange **Children** (0-12) |
| FileMaker `Teens`; Story Share `13-17` | AgeRange **Teens** (13-17) |
| FileMaker `Adults`; Story Share `18+`, `Adult` | AgeRange **Adults** (18+) |
| FileMaker `Elders` | AgeRange **Elders** (65+) |
| FileMaker `C & T` | AgeRange **Children** *and* **Teens** |
| FileMaker `Families` | AgeRange **Children**, **Teens**, **Adults** *and* **Elders** — serving families is serving every age |
| Story Share `Family windows` | StoryPopulation **Families** (a story can carry a population; a person can't) |
| Story Share `Mixed-age groups`, `Combined` | nothing — says the group was mixed, not which ages |

`3-5` and `6-12` were folded into `Children` in the portal, and the `StoryPopulation`
twins carry a trailing underscore so the clean age names stay free (see `db/seeds.rb`).

## How it's stored

**`TagAlias` rows, not a constant.** Each row names one legacy term, the tag it resolves
to (polymorphic — a `Sector` or an `AgeRange` `Category`), and the system the term came
from. `TagTranslation` reads a tag's own name first, then the aliases.

- **A tag resolves by name only while it's published.** A retired tag is unpublished rather
  than deleted so its old taggings survive, and matching one by name would hand it to
  hundreds of new records by accident. **A recorded alias may point at a retired tag** —
  that's someone deciding the term means that tag, which is the opposite of an accident.
  `Poverty` is exactly that case: the sector is retired, 634 archive rows name it, and the
  alias sends them to the tag that already carries its older taggings.

- **A term can name two tags**, so a row per pair and a list on the way out (`C & T`).
- **Unique on (term, tag)**, with the column's case-insensitive collation, so one spelling
  can't be recorded twice for the same tag.
- **An admin can add a term** as it turns up, without a deploy — which matters, because the
  archive's free-text tail keeps producing new ones.
- **`created_by` and `created_at`** make it the record of who decided a term meant a tag
  and when. The renames and merges already ran, so the old names are gone from the data;
  these rows are what's left of them.
- **A term can be recorded as naming nothing on purpose** (`ignored`). That's how the
  dropped Settings and `Other` stay out of the queue of terms still needing a decision —
  without it, ~2,800 mentions of "Virtually", "Outreach Program" and the like would bury
  the handful that genuinely need one.
- `TagAliasSeeder` (and `data:seed_tag_aliases`) records the tables above, idempotently,
  and never touches a term an admin added.

The tables stay here as the readable source; the rows are the machine-readable copy.

## What the archive actually holds

Counted across `fm_rolodexes` (October 2026): `LifeExperiences` 55 distinct values /
21,857 mentions · `Settings` 161 / 6,082 · `PrimaryAgeGroup` 11 / 2,356 ·
`PrimaryServiceArea` 29 / 2,354 · `OtherServiceArea` 73 / 75.

- **The canonical words dominate.** The documented vocabulary covers nearly every mention;
  134 of the 161 `Settings` values occur exactly once.
- **`OtherServiceArea` is free text**, not a picker: 72 of its 73 values occur once, across
  75 rows in all. Not worth translating — it goes to the unmatched report.
- **`Other`** appears as a stored value (90 `PrimaryServiceArea`, 60 `LifeExperiences`).
  It is recorded as ignored rather than translated: `Sector::OTHER_SECTOR_NAME` is offered
  for additional sectors but never as a primary, so an import can't honour it as one, and
  "they picked Other" says nothing a tag could carry.
- **Still needing a decision** — 23 terms, one mention each, every one naming an
  organization, a place that identifies one, or a facilitator's own circumstances. They stay
  in the archive and show up in the unmatched report; nothing is copied out of them.
- **The proposed reads need a pass with staff** before the real import run. They resolve
  meanwhile, so the work isn't blocked, and a wrong one is a row to delete rather than a
  deploy.
- **Coverage.** 17,734 of the archive's 17,757 mentions are translated, deliberately
  untranslated, or proposed.
- **Seen in the data, no mapping decided:** Children's Services, Intellectual Disabilities,
  Maternal wellness and postpartum support, Political Asylum, Survivors with Disabilities,
  Arts Education & Community Art Making, and the rest of the one-off free text. Deliberately
  unseeded — each is a judgment call for AWBW, and the unmatched report is the queue.

## Consequences

- **Populations are not age ranges.** `AgeGroupTaggable` only tags `AgeRange` categories, so
  a person has no population tag to carry `Families`. Rather than drop it, a person whose
  FileMaker age group is `Families` is tagged with every age range — which is what serving
  families means. A story keeps its `StoryPopulation` tag.
- **One source value can produce several tags** (`C & T`, `Families`, the compound cells),
  so a translator returns a list, not a value — and across both vocabularies, since a sector
  field can carry an age term.
- **Unmapped values need a report, not a fallback.** `PersonServices::ImportFromRolodex`
  counts them in `#unmatched_tags` and the rake task prints them ranked; its name matching
  alone resolves only the values that already read as a sector name.
- **The translation is data, so it can retire.** Once the imports and backfills are done,
  the rows stay as the history of what a tag used to be called — and can be dropped without
  touching code if that history stops being useful.
