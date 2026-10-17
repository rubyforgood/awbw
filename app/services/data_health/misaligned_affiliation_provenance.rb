module DataHealth
  # Affiliations whose minting registration is not linked to the affiliation's own
  # organization. ADR-0003 D2a's invariant is "FK present ⟺ this row was auto-minted
  # for its *current* organization", and reconciliation's auto-vs-manual gate reads
  # that FK — so a stale link makes a row look auto-minted for an org it was never
  # minted for.
  #
  # `reset_org_scoped_links_on_org_change` clears the FK when an admin repoints the
  # org through the affiliation editor. Rows that predate that guard, or that were
  # repointed another way, are what this finds. Report-only: whether the person or
  # the registration's linked organizations is wrong is a call made per row.
  class MisalignedAffiliationProvenance < Check
    def title = "Affiliations linked to a registration for another organization"

    def explanation
      "The registration recorded as creating each row is not linked to that row's organization, " \
      "so reconciliation treats it as auto-created for an organization it never belonged to. " \
      "Fix the person's affiliations or the registration's linked organizations."
    end

    def scope
      linked = EventRegistrationOrganization
        .where("event_registration_organizations.event_registration_id = affiliations.event_registration_id")
        .where("event_registration_organizations.organization_id = affiliations.organization_id")

      Affiliation.where.not(event_registration_id: nil)
        .where.not(linked.arel.exists)
        .includes(:person, :organization, event_registration: :event)
    end

    def row_partial = "admin/data_health/misaligned_affiliation_row"

    def describe(affiliation)
      "#{affiliation.person&.name} — #{affiliation.organization&.name} " \
      "(linked to a registration for #{affiliation.event_registration&.event&.title})"
    end
  end
end
