# Turns a legacy word for who someone serves into the portal's own tags: the archive's
# service areas and settings, the older forms' prose labels, Story Share's categories, and
# the portal's earlier sector names. A term resolves by a tag's own name or by any
# TagAlias recorded for it (ADR-0007), and one term can name several tags.
#
# A tag resolves **by name only while it's published**. A retired tag is unpublished rather
# than deleted, so its old taggings survive, and matching one by name would let an import
# hand it to hundreds more records by accident. A recorded alias is the opposite — someone
# decided that term means that tag — so an alias may point at a retired tag and still
# resolve. FileMaker's "Poverty" works that way: the sector it means is retired, and 634
# archive rows name it.
#
# A term is read without regard for the field it sat in, because the two vocabularies cross:
# FileMaker's "Elder Abuse" is a life experience that means the Elders *age range*, and
# "Children's Services" is a service area that means the Children one. So #resolve answers
# with both kinds and the caller takes what it needs — and whether a tag lands as primary or
# additional stays the caller's call, since that follows from the field, not the term.
#
# Built once and reused — it reads the whole sector and age-group vocabulary up front, so
# a 39,000-row import doesn't query per value. A term nothing answers to is counted in
# #unmatched rather than guessed at — unless it's recorded as ignored, which is how a
# decided non-translation stays out of the queue of terms still needing a decision.
class TagTranslation
  Tags = Data.define(:sector_ids, :age_group_ids)

  # FileMaker repeating fields separate values with line breaks, and a hand-typed list
  # uses semicolons. Commas are not separators: the wording itself contains them, inside
  # parentheticals like "Community violence (gang violence, mass shootings, etc.)".
  SEPARATORS = /[;\r\n]+/
  # The clarifying tail a form added to a term, dropped when the term alone resolves.
  PARENTHETICAL = /\s*\([^)]*\)?\s*\z/

  attr_reader :unmatched

  def initialize
    @sectors = vocabulary(Sector.published)
    @age_groups = vocabulary(Category.age_ranges.published)
    @ignored = TagAlias.ignored.pluck(:name).map { |name| key(name) }.to_set
    @unmatched = Hash.new(0)
  end

  def resolve(value)
    sector_ids = []
    age_group_ids = []

    terms(value).each do |term|
      sectors = lookup(@sectors, term)
      age_groups = lookup(@age_groups, term)
      @unmatched[term] += 1 if sectors.empty? && age_groups.empty? && !@ignored.include?(term)
      sector_ids.concat(sectors)
      age_group_ids.concat(age_groups)
    end

    Tags.new(sector_ids: sector_ids.uniq, age_group_ids: age_group_ids.uniq)
  end

  private

  def lookup(index, term)
    index[term] || index[key(term.sub(PARENTHETICAL, ""))] || []
  end

  # Names come from the scope as given (published only); aliases are read across the whole
  # vocabulary of that kind, so one can deliberately point at a retired tag.
  def vocabulary(scope)
    aliases = TagAlias.resolving.where(aliasable_type: scope.model_name.to_s,
                                       aliasable_id: scope.unscope(where: :published).select(:id))
    (scope.pluck(:name, :id) + aliases.pluck(:name, :aliasable_id)).each_with_object({}) do |(name, id), index|
      (index[key(name)] ||= []) << id
    end
  end

  def terms(value)
    value.to_s.split(SEPARATORS).filter_map { |part| key(part).presence }.uniq
  end

  def key(value)
    value.to_s.squish.downcase
  end
end
