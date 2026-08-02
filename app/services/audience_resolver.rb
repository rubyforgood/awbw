require "set"

# Turns a composition's audience recipe into a concrete set of people.
#
# The recipe is an ordered list of { field, value, join } combined left→right,
# exactly like the recipients builder: OR unions, AND intersects, AND NOT
# subtracts. Manual add/exclude overrides are then applied on top (add wins).
# Only emailable people are returned.
#
# Field predicates live in FIELDS so new filters are declarative. This starts
# with the always-safe Person text columns; the fuller registry (county, portal
# access, role, and the event-scoped registrant fields) is added as each maps to
# a verified query.
class AudienceResolver
  # field name => ->(value) { array of matching Person ids }
  FIELDS = {
    "first_name" => ->(v) { AudienceResolver.text_ids(:first_name, v) },
    "last_name"  => ->(v) { AudienceResolver.text_ids(:last_name, v) },
    "email"      => ->(v) { AudienceResolver.text_ids(:email, v) }
  }.freeze

  def self.people_for(composition)
    new(composition).people
  end

  # Text search over a Person column, honoring the "a--b" multi-value convention
  # (match ANY token). Column names come from FIELDS, never user input.
  def self.text_ids(column, value)
    tokens = value.to_s.split("--").map(&:strip).reject(&:blank?)
    return [] if tokens.empty?

    tokens.reduce(Person.where("1 = 0")) { |rel, token|
      rel.or(Person.where("#{column} LIKE ?", "%#{token}%"))
    }.pluck(:id)
  end

  def initialize(composition)
    @composition = composition
  end

  def people
    Person.where(id: resolved_ids.to_a).select { |person| person.preferred_email.present? }
  end

  # The matched person ids (a Set), before the emailable filter. Exposed for
  # preview counts.
  def resolved_ids
    ids = fold_segments
    ids.subtract(@composition.excluded_ids)
    ids.merge(@composition.added_ids)
    ids
  end

  private

  def fold_segments
    active = @composition.segments.select { |seg| FIELDS.key?(seg["field"]) && seg["value"].present? }
    return Set.new if active.empty?

    result = Set.new(ids_for(active.first))
    active.drop(1).each do |seg|
      set = Set.new(ids_for(seg))
      case seg["join"]
      when "AND"     then result &= set
      when "AND NOT" then result -= set
      else                result |= set # OR (also the base/first segment)
      end
    end
    result
  end

  def ids_for(segment)
    FIELDS.fetch(segment["field"]).call(segment["value"])
  end
end
