# Features & tips seeds

Seed files for the **Features & tips** page (`/features`), one YAML file per feature.

**These files are seeds, not the page's data.** The page reads the `features`
table, and super-admins edit those records in-app (rich descriptions, screenshots,
doc links). An admin clicks **Sync latest updates** on `/features`
(`FeatureCatalog#import!`) to hydrate the table from these files:

- Creates a record for any seed whose `name` isn't in the table yet.
- Overwrites a same-name record with the seed's fields when nobody has edited
  it in-app. A field the seed leaves blank keeps its value.
- Never touches a record an admin has edited.

The table is never regenerated from this folder. Deleting or renaming a file
leaves its record in place; renaming a feature's `name` here creates a new record.

## Adding a feature

Optional for contributors: maintainers can add it if you skip it.

When you ship a user-facing feature **or** improvement, add a new file:
`YYYY-MM-DD-short-slug.yml`, named with the ship date and a slug of the name.
One file per feature keeps parallel PRs from conflicting.

`display_status` is who the **announcement** is for, not who the feature is for.

- Admins see every entry — it's their full changelog.
- `user_facing` (logged-in users) and `public_facing` (everyone) are release announcements.
- **Every change** → one entry, `admin_facing`.
- **Big feature** → also add a second file, `user_facing` or `public_facing`, with a
  different `name` and the same `released_on`, written for users.
  - Put the audience after the date: `YYYY-MM-DD-user-slug.yml` or `YYYY-MM-DD-public-slug.yml`.

```yaml
name: "Filter registrants by registration date"
area: registration
display_status: admin_facing
released_on: 2026-10-17
pr_number: 1234
action_path: "/events"
summary: >-
  One or two plain-language sentences shown on the card.
pro_tips:
  - "Optional short, practical tip."
```

| Field | Notes |
|---|---|
| `name` | Short, sentence-case, unique. The sync matches records by it. |
| `area` | One of `Feature::AREA_KEYS` (events, registration, scholarships, payments, people, content, stories, communications, reporting). |
| `display_status` | Announcement audience: `admin_facing` (default; super-admins only), `user_facing`, or `public_facing`. |
| `summary` | One or two plain-language sentences, max 300 characters (the model rejects longer). Put longer detail in `description`. |
| `released_on` | Ship date (`YYYY-MM-DD`). |
| `action_path` | Optional in-app path for "Check out this feature". Use `/registration/sample` for ticket/callout features. |
| `pr_number` | Optional GitHub PR number (adds a pull request link). |
| `pro_tips` | Optional list of short tips (0–2 is plenty). |
| `description` | Optional longer write-up (plain text or HTML). |
| `external_url` | Optional link to a full process doc. |
