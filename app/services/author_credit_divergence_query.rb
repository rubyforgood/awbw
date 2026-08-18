# Content whose credit doesn't resolve cleanly through a profile, in four sections:
#
#   preference   — snapshot no longer matches the profile
#   legacy       — credited by a free-text name column, no person at all
#   creator      — author_id blank, credited generically, creator suggested to assign
#   unattributed — nothing to credit at all
#
# Comparisons run in Ruby because they walk the author fallback chain.
class AuthorCreditDivergenceQuery
  # Doubles as the allowlist for the `type` param — never constantize a raw param.
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

  # Which preference reveals the least, for suggesting one that fits all their content.
  RESTRICTIVENESS = {
    "anonymous" => 4,
    "last_name_only" => 3,
    "first_name_only" => 3,
    "first_name_last_initial" => 2,
    "full_name" => 1
  }.freeze

  PersonGroup = Struct.new(:person, :records, :suggested_preference, keyword_init: true)

  # Kept even when empty — clearing a column is what makes it safe to drop.
  LegacyGroup = Struct.new(:model, :column, :entries, keyword_init: true) do
    def empty? = entries.empty?
    def field = column.split(".").last
  end
  AssignableRow = Struct.new(:record, :suggested_author, keyword_init: true)

  Result = Struct.new(:preference, :legacy, :creator, :unattributed, keyword_init: true) do
    def legacy_empty? = legacy.all?(&:empty?)

    def empty?
      preference.empty? && legacy_empty? && creator.empty? && unattributed.empty?
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
      legacy: legacy_groups,
      creator: creator_groups,
      unattributed: unattributed_records
    )
  end

  private

  attr_reader :person_id, :type, :preference, :include_reconciled

  def models
    @models ||= type ? [ self.class.model_for(type) ].compact : MODEL_NAMES.map(&:constantize)
  end

  # The idea models have no author_id, so they credit generically — there's no
  # author to reconcile, so they're left out of every section.
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

  def preference_groups
    records = models.flat_map do |model|
      scope = scoped(model).where.not(author_credit_preference: nil)
      scope = scope.where(author_credit_preference: preference) if preference
      scope.select(&:author_credit_diverged?)
    end

    group_by_person(records)
  end

  # No credited person here, which is the whole problem — so no person filter.
  def legacy_groups
    groups = authorable_models.flat_map do |model|
      model.legacy_author_name_columns.map { |column| [ model, column ] }
    end

    records = preference || person_id ? [] : legacy_candidates
    suggestions = suggested_authors_for(records)

    groups.map do |model, column|
      entries = records.select { |record| record.is_a?(model) }.map do |record|
        AssignableRow.new(record: record, suggested_author: suggestions[normalized(record.legacy_author_name_text)])
      end
      LegacyGroup.new(model: model, column: column, entries: entries)
    end
  end

  def legacy_candidates
    authorable_models.flat_map do |model|
      next [] if model.legacy_author_name_columns.empty?
      sorted(scoped(model).where(author_id: nil).select { |record| record.legacy_author_name_text.present? })
    end
  end

  # Guess who each free-text name means, in one query for the page, not one per row.
  def suggested_authors_for(records)
    names = records.filter_map { |record| record.legacy_author_name_text.presence }.uniq
    return {} if names.empty?

    candidates = Person.where(last_name: names.flat_map { |name| name.split(/\s+/) }.uniq)
    by_normalized_full_name = candidates.index_by { |person| normalized(person.full_name) }

    names.index_with { |name| by_normalized_full_name[normalized(name)] }
         .transform_keys { |name| normalized(name) }
  end

  def normalized(value)
    value.to_s.downcase.gsub(/\s+/, "")
  end

  # Grouped by the creator as a *suggestion*, not as a governing profile — the credit
  # itself already shows the generic label, since nobody claimed these.
  def creator_groups
    records = authorable_models.flat_map do |model|
      scoped(model)
        .where(author_id: nil)
        .select { |record| record.legacy_author_name_text.blank? && record.created_by&.person.present? }
    end

    group_by_person(records) { |record| record.created_by.person }
  end

  def unattributed_records
    return [] if preference || person_id

    authorable_models.flat_map do |model|
      sorted(scoped(model)
        .where(author_id: nil)
        .select { |record| record.legacy_author_name_text.blank? && record.created_by&.person.blank? })
    end
  end

  def group_by_person(records, &grouper)
    records
      .group_by(&(grouper || :credit_governing_person.to_proc))
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
