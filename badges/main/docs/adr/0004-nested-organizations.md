# ADR-0004 — Nested organizations (a self-referential org tree)

- **Status:** Accepted
- **Date:** 2026-08-31

## Context

FileMaker is the source of truth we're importing from (rubyforgood/awbw#508).
There, `Organization` records carry a `ParentID` self-reference and also own
`Project` records. Staff historically split one real organization into two
FileMaker Projects when it ran both Adult and Children's Windows programs; they
now want those grouped "under one roof." When the FileMaker Organizations import
lands, both the org→org parent chain and the org→project ownership collapse into
the single Rails `Organization` model, so that model needs a way to nest.

## Decisions

### D1 — Adjacency-list tree on `organizations`

Nesting is one nullable `organizations.parent_id` self-FK (`belongs_to :parent`,
`has_many :children`), not a join table, closure table, or STI. It's the
lightest seam that mirrors FileMaker's `ParentID` one-to-one and keeps re-parenting
a single column write. Arbitrary depth is allowed (matching FileMaker), traversed
with `#ancestors` / `#descendants` / `#root` helpers.

### D2 — Structural only for now

The parent/child link is navigation and grouping only. A parent org does **not**
aggregate its children's affiliations, sectors, age groups, workshops, or events
into its own profile/index rows. Roll-ups are a deliberate later change if the need
appears; keeping the first cut structural avoids touching every aggregate scope and
decorator before we know the import shape.

### D3 — Deleting a parent un-nests its children

`has_many :children, dependent: :nullify`. Removing a roof org must never cascade
and destroy the real programs nested under it; the children survive as top-level
orgs.

### D4 — Cycle protection at the model

`parent_id` can't be the org itself or one of its own descendants
(`parent_is_not_self_or_descendant`). The traversal helpers also guard against a
malformed stored cycle so a bad row can't loop forever.

### D5 — Set the parent from the edit form

Admins nest an org via a "Parent organization" remote-select picker on the org
edit form (admin-gated, same `remote-select` pattern as the workshop picker), which
excludes the org itself and its descendants. The profile shows the relationship
read-only in both directions: a "Part of …" link up to the parent and a "Nested
organizations" list down to the children. A dedicated "nest"/"demote" button is
deferred — the picker plus two-way profile links already cover moving through the
tree.
