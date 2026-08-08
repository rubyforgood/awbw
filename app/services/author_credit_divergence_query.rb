# Everything on the author credit divergences page: content whose credit doesn't
# resolve cleanly through the credited person's profile.
#
# Four sections, in the order an admin should work them. The first is about a
# preference that drifted; the other three are all forms of "this credit isn't
# coming from an author_id", which is the only path that links to a profile and
# lists the record on it.
#
#   preference   — stored consent snapshot no longer matches the profile
#   legacy       — credited by a free-text name column, no person at all
#   creator      — author_id is blank, so the credit falls back to the creator
#   unattributed — nothing to credit; renders the model's missing_author_label
#
# Comparisons run in Ruby because they walk the author fallback chain. The
# candidate sets are small: the preference column was added with no default and
# no backfill, and the legacy columns only hold pre-person data.
class AuthorCreditDivergenceQuery
  # Every AuthorCreditable model. Doubles as the allowlist for the `type` param —
  # never constantize a raw param.
  MODEL_NAMES = %w[
    Story
    StoryIdea
    Workshop
    WorkshopIdea
    WorkshopVariation
    WorkshopVariationIdea
    Resource
    CommunityNews
  ].freeze

  SECTIONS = %w[preference legacy creator unattributed].freeze

  # Which preference reveals the least, for suggesting a profile value that
  # satisfies all of a person's content.
  RESTRICTIVENESS = {
    "anonymous" => 4,
    "last_name_only" => 3,
    "first_name_only" => 3,
    "first_name_last_initial" => 2,
    "full_name" => 1
  }.freeze

  PersonGroup = Struct.new(:person, :records, :suggested_preference, keyword_init: true)
  Result = Struct.new(:preference, :legacy, :creator, :unattributed, keyword_init: true) do
    def empty?
      preference.empty? && legacy.empty? && creator.empty? && unattributed.empty?
    end
  end

  def self.model_for(type)
    MODEL_NAMES.include?(type.to_s) ? type.to_s.constantize : nil
  end

  def initialize(person_id: nil, type: nil, preference: nil, include_reconciled: false)
    @person_id = person_id.presence
    @type = type.presence
    @preference = preference.presence
    @include_reconciled = ActiveModel::Type::Boolean.new.cast(include_reconciled)
  end

  def call
    Result.new(
      preference: preference_groups,
      legacy: legacy_records,
      creator: creator_groups,
      unattributed: unattributed_records
    )
  end

  private

  attr_reader :person_id, :type, :preference, :include_reconciled

  def models
    @models ||= type ? [ self.class.model_for(type) ].compact : MODEL_NAMES.map(&:constantize)
  end

  # Only models that actually have an author_id can be "missing" one — the idea
  # models have no such column, so crediting through the creator is their normal
  # and correct behavior, not something to resolve.
  def authorable_models
    models.select { |model| model.column_names.include?("author_id") }
  end

  def scoped(model)
    model.includes(includes_for(model))
  end

  def includes_for(model)
    includes = [ { created_by: :person } ]
    includes << :author if model.column_names.include?("author_id")
    includes
  end

  # ── Section 1: the stored snapshot drifted from the profile ────────────────
  def preference_groups
    records = models.flat_map do |model|
      scope = scoped(model).where.not(author_credit_preference: nil)
      scope = scope.where(author_credit_preference: preference) if preference
      scope.select(&:author_credit_diverged?)
    end

    group_by_person(records)
  end

  # ── Section 2: credited by a free-text name, with no person behind it ──────
  # The person filter can't apply here: these records have no credited person,
  # which is the whole problem with them.
  def legacy_records
    return [] if preference || person_id

    authorable_models.flat_map do |model|
      next [] if model.legacy_author_name_columns.empty?
      sorted(scoped(model).where(author_id: nil).select { |record| record.legacy_author_name_text.present? })
    end
  end

  # ── Section 3: author_id blank, so the credit falls back to the creator ────
  def creator_groups
    records = authorable_models.flat_map do |model|
      scoped(model)
        .where(author_id: nil)
        .select { |record| record.legacy_author_name_text.blank? && record.created_by&.person.present? }
    end

    group_by_person(records)
  end

  # ── Section 4: nothing to credit at all ────────────────────────────────────
  def unattributed_records
    return [] if preference || person_id

    authorable_models.flat_map do |model|
      sorted(scoped(model)
        .where(author_id: nil)
        .select { |record| record.legacy_author_name_text.blank? && record.created_by&.person.blank? })
    end
  end

  def group_by_person(records)
    records
      .group_by(&:author_person)
      .filter_map { |person, grouped| build_group(person, grouped) }
      .sort_by { |group| [ group.person.first_name.to_s.downcase, group.person.last_name.to_s.downcase ] }
  end

  def build_group(person, records)
    return nil if person.blank?
    return nil if person_id.present? && person.id != person_id.to_i
    return nil if person.author_credit_reconciled_at.present? && !include_reconciled

    PersonGroup.new(
      person: person,
      records: sorted(records),
      suggested_preference: most_restrictive(records)
    )
  end

  def sorted(records)
    records.sort_by { |record| [ record.class.name, record.id ] }
  end

  def most_restrictive(records)
    records.map(&:author_credit_preference).compact.max_by { |value| RESTRICTIVENESS.fetch(value, 0) }
  end
end
