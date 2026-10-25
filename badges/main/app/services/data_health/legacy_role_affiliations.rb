module DataHealth
  # Affiliations still titled with one of the old app's roles, which the January 2026
  # conversion copied into titles: a Leader or Liaison was a Facilitator who is a primary
  # contact, an Assistant a Facilitator who isn't. None of those titles counts toward program
  # status. Report-only: each row shows the person's Facilitator rows at that organization and
  # opens their edit page to settle by hand.
  class LegacyRoleAffiliations < Check
    LEGACY_TITLES = %w[Leader Liaison Assistant default].freeze

    def title = "Affiliations still titled with an old-app role"

    def explanation
      "The old app's Leader, Liaison and Assistant roles (and its blank \"default\") became titles in " \
      "January, but only a Facilitator affiliation counts toward program status. Each row is listed " \
      "with the person's Facilitator rows at that organization; open the person to merge, rename or remove it."
    end

    def scope
      Affiliation.where(title: LEGACY_TITLES).includes(:person, :organization).order(:title, :organization_id, :person_id, :id)
    end

    def self.legacy_title?(title)
      LEGACY_TITLES.any? { |legacy| legacy.casecmp?(title.to_s.squish) }
    end

    def row_partial = "admin/data_health/legacy_role_row"

    def describe(affiliation)
      "#{affiliation.person&.name} — #{affiliation.organization&.name} (#{affiliation.title})"
    end

    # The person's Facilitator rows at the affiliation's organization, oldest first.
    def facilitators_for(affiliation)
      Affiliation.facilitators.where(person_id: affiliation.person_id, organization_id: affiliation.organization_id)
                 .order(:start_date, :id).to_a
    end

    # How many organizations other than this one the person facilitates at.
    def facilitator_elsewhere_count(affiliation)
      Affiliation.facilitators.where(person_id: affiliation.person_id).where.not(organization_id: affiliation.organization_id)
                 .distinct.count(:organization_id)
    end

    # The Facilitator row recording the same stretch (AffiliationStint), the same dates first.
    def twin_for(affiliation, facilitators = facilitators_for(affiliation))
      stint = AffiliationStint.of(affiliation)
      facilitators.select { |facilitator| AffiliationStint.of(facilitator).overlap?(stint) }
                  .min_by { |facilitator| same_dates?(facilitator, affiliation) ? 0 : 1 }
    end

    def stretch_label(facilitator, affiliation, twin)
      return "same dates" if same_dates?(facilitator, affiliation)
      return "overlaps with different dates" if facilitator == twin

      "a different stretch"
    end

    def same_dates?(facilitator, affiliation)
      facilitator.start_date == affiliation.start_date && facilitator.end_date == affiliation.end_date
    end
  end
end
