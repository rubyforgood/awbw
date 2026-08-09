# Groups a set of scholarships for the index into the two-level hierarchy the
# page renders: funder (the grant's funder) → grant → recipient rows. A funder
# can hold several grants (e.g. a funder who funds a new grant each year), so
# grants are nested under their shared funder rather than flattened.
#
# Scholarships drawn from no grant have no funder; they collect under a single
# "Unfunded" group, which always sorts last.
class ScholarshipsGrouping
  UNFUNDED_LABEL = "Unfunded".freeze

  GrantGroup = Struct.new(:grant, :scholarships, keyword_init: true) do
    def total_cents = scholarships.sum { |s| s.amount_cents.to_i }
    def count = scholarships.size
  end

  FunderGroup = Struct.new(:name, :funder, :grant_groups, keyword_init: true) do
    def total_cents = grant_groups.sum(&:total_cents)
    def count = grant_groups.sum(&:count)
  end

  def initialize(scholarships)
    @scholarships = scholarships.to_a
  end

  def funder_groups
    @funder_groups ||= @scholarships
      .group_by { |s| funder_key(s) }
      .map { |_key, scholarships| build_funder_group(scholarships) }
      .sort_by { |group| sort_key(group) }
  end

  private

  def build_funder_group(scholarships)
    sample_grant = scholarships.filter_map(&:grant).first
    FunderGroup.new(
      name: sample_grant&.funder_name.presence || UNFUNDED_LABEL,
      funder: sample_grant&.funder,
      grant_groups: grant_groups_for(scholarships)
    )
  end

  def grant_groups_for(scholarships)
    scholarships
      .group_by(&:grant)
      .map { |grant, schs| GrantGroup.new(grant: grant, scholarships: by_recipient_name(schs)) }
      .sort_by { |group| group.grant&.name.to_s.downcase }
  end

  def by_recipient_name(scholarships)
    scholarships.sort_by { |s| s.recipient&.full_name.to_s.downcase }
  end

  # Scholarships from grants by the same funder share a funder; grant-free ones
  # fall into the single unfunded bucket.
  def funder_key(scholarship)
    grant = scholarship.grant
    return :unfunded unless grant

    [ grant.funder_type, grant.funder_id ]
  end

  # Alphabetical by funder, with the unfunded group pinned last.
  def sort_key(group)
    [ group.name == UNFUNDED_LABEL ? 1 : 0, group.name.to_s.downcase ]
  end
end
