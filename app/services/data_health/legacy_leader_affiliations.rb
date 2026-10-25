module DataHealth
  # Affiliations still titled Leader, the old app's word for a Facilitator who is a
  # primary contact. Settled row by row on the Leader affiliations page.
  class LegacyLeaderAffiliations < Check
    def title = "Affiliations still titled Leader"

    def explanation
      "A Leader is a Facilitator who is a primary contact, but a row titled Leader counts toward " \
      "no program status. Review them to merge each into its Facilitator row, rename it, end it, " \
      "or delete it — previewing every change before it's made."
    end

    def scope = AffiliationServices::FoldLegacyLeaders.legacy.includes(:person, :organization)

    def review_path = admin_leader_affiliations_path

    def describe(affiliation)
      "#{affiliation.person&.name} — #{affiliation.organization&.name}"
    end
  end
end
