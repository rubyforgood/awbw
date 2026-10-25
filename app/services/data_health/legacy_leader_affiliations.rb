module DataHealth
  # Affiliations still titled Leader, the old app's word for a Facilitator who is a
  # primary contact. Report-only: each row shows the Facilitator row beside it, if any, and
  # opens the person's edit page to settle by hand.
  class LegacyLeaderAffiliations < Check
    LEGACY_TITLE = "Leader".freeze

    def title = "Affiliations still titled Leader"

    def explanation
      "A Leader is a Facilitator who is a primary contact, but a row titled Leader counts toward " \
      "no program status. Each one is listed with the Facilitator row beside it; open the person to " \
      "merge, rename or remove it."
    end

    def scope
      Affiliation.where(title: LEGACY_TITLE).includes(:person, :organization).order(:organization_id, :person_id, :id)
    end

    def row_partial = "admin/data_health/legacy_leader_row"

    def describe(affiliation)
      "#{affiliation.person&.name} — #{affiliation.organization&.name}"
    end

    # The Facilitator row recording the same stretch (AffiliationStint), the same dates first.
    def twin_for(leader)
      stint = AffiliationStint.of(leader)
      Affiliation.facilitators.where(person_id: leader.person_id, organization_id: leader.organization_id)
                 .select { |affiliation| AffiliationStint.of(affiliation).overlap?(stint) }
                 .min_by { |affiliation| same_dates?(affiliation, leader) ? 0 : 1 }
    end

    def same_dates?(affiliation, leader)
      affiliation.start_date == leader.start_date && affiliation.end_date == leader.end_date
    end
  end
end
