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

- Compare case-insensitively, ignoring surrounding whitespace.
- One field may list several areas: split on commas, semicolons and line breaks (FileMaker
  repeating fields are newline-separated), then translate each piece.
- Many source values mapping to one tag is normal. Only `C & T` maps to two tags.
- The portal spelling wins where the spreadsheet differs: **`Systems/Policy Change`** (the
  sheet's "Sytems" is a typo).
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
| Racism and Marginalization | Racial/Social Justice |
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
| FileMaker `Families`; Story Share `Family windows` | StoryPopulation **Families** |
| Story Share `Mixed-age groups`, `Combined` | nothing — says the group was mixed, not which ages |

`3-5` and `6-12` were folded into `Children` in the portal, and the `StoryPopulation`
twins carry a trailing underscore so the clean age names stay free (see `db/seeds.rb`).

## Consequences

- **Populations are not age ranges.** `AgeGroupTaggable` only tags `AgeRange` categories, so
  a person whose FileMaker age group is `Families` gets no age tag — `Families` is a story
  population, and people have no population tagging. An importer reports it rather than
  forcing it into an age range.
- **One source value can produce two tags** (`C & T`), so a translator returns a list, not a
  value.
- **Unmapped values need a report, not a fallback.** `PersonServices::ImportFromRolodex`
  counts them in `#unmatched_tags` and the rake task prints them ranked; its name matching
  alone resolves only the values that already read as a sector name.
- The tables above are the specification for that lookup. Keep them in one constant so the
  Rolodex import, a later forms backfill, and any Story Share migration share it.
