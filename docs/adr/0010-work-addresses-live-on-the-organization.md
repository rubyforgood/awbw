# ADR-0010 — Work addresses live on the organization

- **Status:** Accepted
- **Date:** 2026-10-25

## Context

A person's work address is where they work, so it belongs to the organization: everyone
there shares it, and it stays when the person leaves. The affiliation already records which
of the organization's addresses a person works at (`affiliations.organization_address_id`,
the person edit page's work address picker).

Before that picker, a work address could only be saved on the person, typed Work. The person
address form now offers Personal or Mailing (ADR-0008), and the FileMaker import lands work
addresses on the organization — but the Work addresses already on people stay there, out of
the picker, unseen by the organization.

## Decision

**A person holds no Work addresses of their own.** Each one already on a person moves to the
organization they work at, once, by a console script — and their affiliation there points at it.

- **Which organization:** the one the person has an active affiliation with (`Affiliation#active?`,
  not just upcoming), when there is exactly one. Several active affiliations at one
  organization count as one. No active affiliation, or active ones at several organizations,
  and the address stays on the person; the run lists it for staff.
- **The move:**
  - An address the organization already holds (same city, and the same street when it has one
    — `FmAddressAttributes.held`, as the import matches) isn't copied: the organization's copy
    takes the person's FileMaker code and the phones linked to it, and the person's copy is
    removed.
  - Otherwise the address itself moves (same record), and is the organization's primary only if
    it has none.
  - An address that's an invoice's bill-to stays: an invoice's bill-to must be its invoicee's
    address.
- **The affiliation:** the person's active affiliations there that name no work address point at
  the best one moved (active first, then most recently edited). One that already names another
  address keeps it and is listed.
- **The person's primary:** when it moved, their best remaining address becomes primary.

The run is one transaction with a dry run first, stamped with the Settings import user, and saves
a report of every row (ADR-0009's cleanup pattern).

## Consequences

- Every work address shows in the person's work address picker and on the organization.
- A person who works at two organizations, or at none right now, can still hold an older Work
  address, typed Work, until staff place it.
- The FileMaker affiliation pass adds a person's typed-work addresses to the organization and
  leaves the person's copy (ADR-0008); a run of this script after it removes that copy.
