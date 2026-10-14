# ADR-0006 — Who can see and edit each person profile field

- **Status:** Accepted
- **Date:** 2026-10-14

## Context

Person profiles open to non-admins in stages: any signed-in user can view a published
profile, and the owner can edit their own (`PersonPolicy#profiles_visible_to_users?`,
on everywhere but production for now). The edit form and the policy had drifted apart.
Owners saw inputs that the policy silently dropped on save, and some inputs hidden from
owners were still accepted from a crafted request (rubyforgood/awbw#2669). This records
which audience can see or edit each field, so the form, the profile, the index, and
`PersonPolicy`'s `params_filter` all agree.

## Decision

Every person field sits in exactly one access tier:

| Tier | Owner | Other signed-in users | Admins |
|---|---|---|---|
| **Always public** | edits | always see | see + edit |
| **Shared by choice** | edits, decides whether to share it with a `profile_show_*` toggle, and still sees it in the collapsible "Hidden from profile" card when off | see only when the toggle is on | always see, in the same card when off |
| **Private** | edits | never see | see + edit |
| **Request a change** | sees read-only, files a `ProfileChangeRequest` | per its share toggle | see + edit, approve requests |
| **Admin-set** | sees read-only, no request path | per its share toggle, or never | see + edit |
| **Admin-only** | never sees | never see | see + edit |

**People choose their own primary sector and primary age range.** Registration and
other forms already ask for both, so the profile lets the owner change them too. Sector
leader is an earned designation, so only admins set it.

**Badges are always public, whatever the share toggles say.** "Sector Leader" shows with
sectors hidden, author badges show with anonymous contributions on, and "Events Attended"
shows with registrations hidden.

### Placing a new field

Ask in order, and stop at the first yes:

1. **Is it internal staff data?** → admin-only.
2. **Does it identify the person or log them in?** → request a change, or admin-set. An
   owner who could set it could claim someone else's records. `email_2` is matched by
   `PersonMatcher` and the duplicate finders, so it's admin-set.
3. **Is it shared with other people's records?** → request a change. An organization's name
   is the same for everyone affiliated with it. Affiliations drive program status
   (ADR-0003).
4. **Otherwise** the owner edits it. Pick always public, shared by choice, or private.

### Enforcement

- **The policy is a denylist.** For non-admins, `PersonPolicy`'s `params_filter` permits the
  full list and then strips `ADMIN_ONLY_FIELDS`, `ADMIN_ONLY_USER_FIELDS` (login account), and
  `ADMIN_ONLY_SECTOR_FIELDS` (the leader flag). Request-a-change, admin-set, and admin-only fields all go on
  these lists.
- **Adding a field to the permit list makes it owner-editable by default**, so classify it
  here and add it to the right strip list in the same change.
- **The form hides exactly what the policy strips.** Admin-only inputs render under
  `allowed_to?(:manage?, Person)` with admin styling. Admin-set and request fields render
  read-only for owners.

### Considered options

- **An allowlist of owner-editable fields.** It's safer by default. It was rejected because
  owners should edit everything that isn't deliberately locked, and the locked set is the
  smaller, more stable list. The trade-off is that a newly permitted field defaults to
  owner-editable (see Enforcement).

## Field grid

What each audience gets today, as of rubyforgood/awbw#2673. "Index" is the people index
(`people_results`). Non-admins only see published people there, and on their own row the
owner sees hidden pieces like an admin does. "Profile" is `people#show`. "Edit" is the
person form.

**Hidden pieces stay visible to the owner and admins.** When a `profile_show_*` toggle is
off, the index marks that cell with an eye-slash, and the profile moves the piece into a
collapsible "Hidden from profile" card (`people/_hidden_from_profile_card`) under the lilac
`admin-or-owner` wash (`DomainTheme` key `admin_or_owner`). The lazy `?section=` frames for
hidden sections authorize on `own_record?`.

**Submitted content is private with no toggle.** Ideas, workshop logs, and monthly reports
always sit under the `admin-or-owner` wash and are never shown to other users. Their
`profile_show_*` columns are unused.

Key: ✅ shown or editable · 🔀 shown only if the owner's `profile_show_*` toggle is on · 👁
shown, or in the "Hidden from profile" card when the toggle is off · 🔒 read-only · 📨
read-only with a "Request a change" link · 🔵 admin-only (admin styling) · — not shown

| Field | Tier | Index · user | Index · admin | Profile · other user | Profile · owner | Profile · admin | Edit · owner | Edit · admin |
|---|---|---|---|---|---|---|---|---|
| First and last name, avatar | Always public | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Badges (years, author, sector leader, …) | Always public (derived) | — | — | ✅ | ✅ | ✅ | — | — |
| Pronouns | Shared by choice | — | — | 🔀 | 👁 | 👁 | ✅ | ✅ |
| Primary email | Request a change | 🔀 | ✅ | 🔀 | 👁 | 👁 | 📨 | 🔒 edited on the user |
| Primary email type | Shared by choice (with the email) | 🔀 | ✅ | 🔀 | 👁 | 👁 | ✅ | ✅ |
| Primary phone | Shared by choice | — | — | 🔀 | 👁 | 👁 | ✅ | ✅ |
| Social media links | Shared by choice | 🔀 | ✅ | 🔀 | 👁 | 👁 | ✅ | ✅ |
| Bio | Shared by choice | — | — | 🔀 | 👁 | 👁 | ✅ | ✅ |
| Sectors, incl. primary ⭐ | Shared by choice | 🔀 primary | primary | 🔀 | 👁 | 👁 | ✅ | ✅ |
| Sector leader 👑 | Admin-set (shown as a badge) | drives the chip | drives the chip | badge | badge | badge | — | 🔵 |
| Age ranges, incl. primary ⭐ | Shared by choice | 🔀 primary | primary | 🔀 | 👁 | 👁 | ✅ | ✅ |
| Professional licenses | Shared by choice (credentials suffix) | — | — | 🔀 suffix | 👁 suffix | 🔵 full list | ✅, 🔒 once tied to CE | ✅ |
| Affiliations, organization name | Request a change | 🔀 | ✅ | 🔀 | 👁 | 👁 | 📨 | ✅ |
| Facilitator since (derived) | Shared by choice | 🔀 year | year | 🔀 | 👁 | 👁 | 🔒 | 🔒 |
| Member since (override) | Admin-set | as the year | as the year | via facilitator since | via facilitator since | ✅ | — | 🔵 with `?admin` |
| Authored work, registrations | Shared by choice | — | admin quick links | 🔀 | 👁 | 👁 | — | — |
| Ideas, workshop logs, monthly reports | Private (own section, no toggle) | — | — | — | ✅ under the wash | ✅ under the wash | — | — |
| Profile search, display-name, and anonymity preferences | Private | — | — | effects only | effects only | 🔵 | ✅ | ✅ |
| `profile_show_*` toggles | Private | — | — | — | — | — | ✅ | ✅ |
| Legal first name, pronunciation, birthday, time zone | Private | — | — | — | — | 🔵 | ✅ | ✅ |
| Addresses, other phones, best time to call | Private | — | — | — | — | 🔵 | ✅ | ✅ |
| Program settings | Private | — | — | — | — | 🔵 | ✅ | ✅ |
| Secondary email | Admin-set | — | — | — | — | 🔵 | 🔒 | ✅ |
| Secondary email type | Private | — | — | — | — | 🔵 | ✅ (with a secondary email) | ✅ |
| Membership | Private | — | filter only | — | ✅ | on the edit page | — | 🔵 |
| Communications | Admin-only (owner sees their own) | — | — | — | — | 🔵 | 🔒 | ✅ |
| Blog contributor | Admin-set (shown as a badge) | — | — | badge | badge | badge | — | 🔵 |
| Staff tags, mailing lists | Admin-only | — | filter only | — | — | 🔵 | — | 🔵 |
| Racial/ethnic identity, FileMaker code | Admin-only | — | — | — | — | 🔵 | — | 🔵 |
| Comments, notes | Admin-only | — | — | — | — | 🔵 | — | 🔵 |
| Login account flags (admin, inactive, linked person, login email, notes) | Admin-only | — | — | — | — | — | — | 🔵 on the user |

Admin-only index filters are `PersonPolicy::ADMIN_ONLY_FILTERS`: role, facilitator status,
membership status, staff tags, and mailing list.

## Known gaps

These places don't yet follow the tiers above:

- **Unused submitted-content columns.** The person `profile_show_workshop_logs` and
  `profile_show_monthly_reports` columns no longer drive anything and can be dropped (the
  idea columns went in rubyforgood/awbw#2680).
