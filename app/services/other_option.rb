# Extracts free-text "Other" answers out of a stored form answer.
#
# When a registrant picks the "Other" option on a form question, their answer is
# folded into "Other: <text>" (see the specify-option Stimulus controller). On the
# sector/category-backed questions the chosen ids are joined with the free text,
# e.g. "5, 12, Other: Equine therapy". Those free-text values can't be Sector or
# Category records, so they never become tags — this pulls them out so they can
# be surfaced alongside the real tags.
module OtherOption
  PREFIX = "Other"

  # The free-text portions of a stored answer, e.g.
  # "5, Other: Equine therapy" => [ "Equine therapy" ]. A bare "Other" with no
  # accompanying text yields nothing.
  def self.texts(submitted_answer)
    submitted_answer.to_s.split(", ").filter_map do |token|
      stripped = token.strip
      next unless stripped.downcase.start_with?("#{PREFIX.downcase}:")
      stripped[(PREFIX.length + 1)..].strip.presence
    end
  end
end
