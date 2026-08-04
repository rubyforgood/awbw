# Finds content whose stored `author_credit_preference` no longer agrees with the
# credited person's profile, grouped by person so an admin can resolve a whole
# person at once.
#
# The comparison runs in Ruby rather than SQL because it walks the author fallback
# chain (explicit author, then the creating user's person). The candidate set is
# small: the column was added with no default and no backfill, so most legacy rows
# are NULL and only the *_idea tables hold a real spread.
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

  # Which preference reveals the least, for suggesting a profile value that
  # satisfies all of a person's items.
  RESTRICTIVENESS = {
    "anonymous" => 4,
    "last_name_only" => 3,
    "first_name_only" => 3,
    "first_name_last_initial" => 2,
    "full_name" => 1
  }.freeze

  Group = Struct.new(:person, :records, :suggested_preference, keyword_init: true)

  def self.model_for(type)
    MODEL_NAMES.include?(type.to_s) ? type.to_s.constantize : nil
  end

  def initialize(person_id: nil, type: nil, preference: nil, include_reconciled: false)
    @person_id = person_id.presence
    @type = type.presence
    @preference = preference.presence
    @include_reconciled = ActiveModel::Type::Boolean.new.cast(include_reconciled)
  end

  # => [Group] sorted by the person's name
  def call
    diverged_records
      .group_by(&:author_person)
      .filter_map { |person, records| build_group(person, records) }
      .sort_by { |group| group.person.full_name.to_s.downcase }
  end

  private

  attr_reader :person_id, :type, :preference, :include_reconciled

  def models
    return [ self.class.model_for(type) ].compact if type
    MODEL_NAMES.map(&:constantize)
  end

  def diverged_records
    models.flat_map { |model| diverged_for(model) }
  end

  # No person_id filter here — a record can be credited through `author_id` *or*
  # through the creating user's person, so the filter has to run after the
  # fallback chain resolves. See `build_group`.
  def diverged_for(model)
    scope = model.where.not(author_credit_preference: nil)
    scope = scope.where(author_credit_preference: preference) if preference
    scope.includes(includes_for(model)).select(&:author_credit_diverged?)
  end

  def includes_for(model)
    includes = [ { created_by: :person } ]
    includes << :author if model.column_names.include?("author_id")
    includes
  end

  def build_group(person, records)
    return nil if person.blank?
    return nil if person_id && person.id != person_id.to_i
    return nil if person.author_credit_reconciled_at.present? && !include_reconciled

    Group.new(
      person: person,
      records: records.sort_by { |record| [ record.class.name, record.id ] },
      suggested_preference: most_restrictive(records)
    )
  end

  def most_restrictive(records)
    records.map(&:author_credit_preference).max_by { |value| RESTRICTIVENESS.fetch(value, 0) }
  end
end
