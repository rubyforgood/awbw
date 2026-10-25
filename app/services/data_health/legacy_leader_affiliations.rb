module DataHealth
  # Affiliations still titled Leader, the old app's word for a Facilitator who is a
  # primary contact. AffiliationServices::FoldLegacyLeaders folds them in; a row it leaves
  # is one overlapping a Facilitator row with different dates.
  class LegacyLeaderAffiliations < Check
    def title = "Affiliations still titled Leader"

    def explanation
      "A Leader is a Facilitator who is a primary contact, but a row titled Leader counts toward " \
      "no program status. Fixing merges each into the Facilitator row with the same dates, or " \
      "renames it Facilitator when none covers its stretch, leaving a comment either way. One that " \
      "overlaps a Facilitator row with different dates stays here to settle by hand."
    end

    def scope = AffiliationServices::FoldLegacyLeaders.legacy.includes(:person, :organization)

    def repairable? = true

    def repair_label = "Fold into Facilitator"

    def repaired_message(number)
      "Folded #{number} Leader #{'affiliation'.pluralize(number)} into Facilitator."
    end

    def repair!
      AffiliationServices::FoldLegacyLeaders.new.call
    end

    def describe(affiliation)
      dates = [ affiliation.start_date, affiliation.end_date ].compact.map(&:to_s).join(" – ").presence
      "#{affiliation.person&.name} — #{affiliation.organization&.name}#{" (#{dates})" if dates}"
    end
  end
end
