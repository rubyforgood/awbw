# The commented portal affiliations carrying each FileMaker affiliation row's code, read once for
# a page of rows.
class FmAffiliationComments
  ARCHIVES = [ FmPersonnel, FmPeopleToOrganization ].freeze

  def initialize(records)
    @codes = records.select { |record| ARCHIVES.include?(record.class) }.map(&:fm_id).uniq
  end

  def affiliations(record)
    return [] unless ARCHIVES.include?(record.class)

    by_code.fetch(record.fm_id, [])
  end

  private

  def by_code
    @by_code ||= @codes.any? ? load_by_code : {}
  end

  def load_by_code
    index = FilemakerCodeIndex.new(Affiliation.with_comments(true))
    ids = @codes.index_with { |code| index.ids(code) }
    affiliations = Affiliation.where(id: ids.values.flatten).includes(:comments).index_by(&:id)
    ids.transform_values { |code_ids| code_ids.filter_map { |id| affiliations[id] } }
  end
end
