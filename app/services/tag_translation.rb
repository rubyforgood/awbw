# Turns a legacy word for who someone serves into the portal's own tags: the archive's
# service areas and settings, the older forms' prose labels, Story Share's categories, and
# the portal's earlier sector names. A term resolves by a tag's own name or by any
# TagAlias recorded for it (ADR-0007), and one term can name several tags.
#
# Only **published** tags resolve. A retired tag is unpublished rather than deleted, so its
# old taggings survive; matching it here would let an import hand it to hundreds more
# records. An archive term that only matches a retired tag reads as unresolved, which puts
# it in front of someone instead of quietly reviving the tag.
#
# Built once and reused — it reads the whole sector and age-group vocabulary up front, so
# a 39,000-row import doesn't query per value. A term nothing answers to is counted in
# #unmatched rather than guessed at — unless it's recorded as ignored, which is how a
# decided non-translation stays out of the queue of terms still needing a decision.
class TagTranslation
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

  def sector_ids_for(value)
    ids_for(value, @sectors)
  end

  def age_group_ids_for(value)
    ids_for(value, @age_groups)
  end

  private

  def vocabulary(scope)
    aliases = TagAlias.resolving.where(aliasable_type: scope.model_name.to_s, aliasable_id: scope.select(:id))
    (scope.pluck(:name, :id) + aliases.pluck(:name, :aliasable_id)).each_with_object({}) do |(name, id), index|
      (index[key(name)] ||= []) << id
    end
  end

  def ids_for(value, index)
    terms(value).flat_map do |term|
      ids = index[term] || index[key(term.sub(PARENTHETICAL, ""))] || []
      @unmatched[term] += 1 if ids.empty? && !@ignored.include?(term)
      ids
    end.uniq
  end

  def terms(value)
    value.to_s.split(SEPARATORS).filter_map { |part| key(part).presence }.uniq
  end

  def key(value)
    value.to_s.squish.downcase
  end
end
