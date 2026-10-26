# Where each person is on a date — where they work, else where they live: every
# affiliation active on that date (today by default), at its picked address
# (Affiliation#organization_address), else its org's oldest active address; with
# none of those, the one address that stands for the person themselves
# (Address#ranked_for_owner — active work, else latest-edited active personal,
# else inactive personal, else inactive work). Event pages pass the event's start
# date so a past event doesn't move when someone changes jobs. The source for
# every person location chart, count, and filter.
class PersonLocations
  # Everything an address says about *where* it is — the whole record bar the
  # street and phone, which identify a building rather than place it. A row
  # carries all of them so a new chart, count, or filter needs only a field name.
  LOCATION_FIELDS = %i[
    city county state country locality zip_code district
    la_city_council_district la_supervisorial_district la_service_planning_area
  ].freeze
  # Fields a filter matches on a case-insensitive substring, because someone types
  # them rather than picking them. The rest come from a list this class built, so
  # they match whole (case-insensitively, as the database's own collation does).
  SEARCHED_FIELDS = %i[ city locality district zip_code ].freeze
  # The prefix someone types for each field. Named for the word rather than the
  # column, the same bargain ContactSearchable strikes — and matching it, so the
  # two boxes on the attendees page read alike even though they answer about
  # different addresses.
  FIELD_PREFIXES = {
    city: :city, county: :county, state: :state, country: :country,
    locality: :locality, zip: :zip_code, district: :district,
    la_council: :la_city_council_district,
    la_supervisorial: :la_supervisorial_district,
    la_spa: :la_service_planning_area
  }.freeze
  # A term with no prefix, which has to match SOMEWHERE on the row. Not a column,
  # so #matching handles it apart from the rest.
  ANY_FIELD = :any
  # `city: austin`, `locality: "Outside CA"`, or a bare term.
  QUERY_TOKEN = /(?:(\w+):\s*)?("[^"]*"|\S+)/
  SEARCH_HINT = "Prefixes: #{FIELD_PREFIXES.keys.map { |prefix| "#{prefix}:" }.join(', ')}. " \
                "All of them have to describe one address. #{ContactSearchable::SEARCH_SYNTAX_HINT}".freeze
  # County filter options carry their state so same-named counties across states
  # don't collide — "CA|Los Angeles" on the registrants roster, "CA::Los Angeles"
  # on the attendees index.
  COUNTY_STATE_SEPARATOR = /::|\|/

  Row = Struct.new(:organization_id, :registrant_id, *LOCATION_FIELDS, keyword_init: true) do
    def city_label
      [ city, state ].compact_blank.join(", ").presence
    end
  end

  # A page's raw location params as fields #matching understands: the county's
  # own state folded into `state`, blanks dropped. Returns nil when nothing can
  # satisfy the combination — the State dropdown naming one state and the County
  # dropdown's own state another.
  def self.filters_from(**filters)
    county_state, county = split_county(filters[:county])
    return nil if filters[:county].present? && county.blank?
    states = [ filters[:state], county_state ].compact_blank.uniq
    return nil if states.many?
    filters.merge(state: states.first, county: county).compact_blank
  end

  def self.split_county(value)
    state, county = value.to_s.split(COUNTY_STATE_SEPARATOR, 2)
    county.nil? ? [ nil, state ] : [ state, county ]
  end

  # A typed query ("city: austin locality: \"Outside CA\"") as fields #matching
  # understands. An unrecognised prefix and a bare term both become ANY_FIELD
  # terms rather than an error — someone mistyping `citty:` should see too much,
  # not an empty page they can't explain.
  def self.parse_query(query)
    query.to_s.scan(QUERY_TOKEN).each_with_object({}) do |(prefix, value), filters|
      field = FIELD_PREFIXES[prefix&.downcase&.to_sym]
      value = value.delete_prefix('"').delete_suffix('"')
      next filters[field] = value if field
      filters[ANY_FIELD] = [ *filters[ANY_FIELD], prefix ? "#{prefix}:#{value}" : value ]
    end
  end

  # Takes the people to locate, as a relation (kept as a subquery, so a
  # whole-population lookup never inlines every id) or as an explicit id array.
  def initialize(people, on: nil)
    @person_ids = if people.is_a?(ActiveRecord::Relation)
      people.except(:includes, :eager_load, :preload, :order, :limit, :offset)
    else
      people
    end
    @on = on
  end

  def rows
    @rows ||= begin
      work = affiliation_triples.filter_map do |person_id, organization_id, address_id|
        address = chosen_addresses[address_id] || oldest_address_by_organization[organization_id]
        row(organization_id, person_id, address) if address
      end
      located = work.map(&:registrant_id).to_set
      home = own_address_by_person.except(*located).map { |person_id, address| row(nil, person_id, address) }
      (work + home).uniq
    end
  end

  # Rows whose one address answers to every field given — so a registrant working
  # in two states can't match a city from one and the county from the other. Pass
  # the whole filter set in one call; chaining two calls is what loses that.
  def matching(**filters)
    filters = filters.compact_blank
    filters.assert_valid_keys(*LOCATION_FIELDS, ANY_FIELD)
    any_terms = Array(filters.delete(ANY_FIELD))
    rows.select do |row|
      filters.all? { |field, value| matches?(row, field, value) } &&
        any_terms.all? { |term| LOCATION_FIELDS.any? { |field| matches?(row, field, term, searched: true) } }
    end
  end

  # Distinct [ state, county ] pairs, sorted, for the County filters.
  def counties
    @counties ||= rows.filter_map { |row| [ row.state, row.county ] if row.state.present? && row.county.present? }.uniq.sort
  end

  # { value => distinct registrant ids } for a location field — the shape every
  # breakdown chart, count, and drill-in reads. Rows with no value sit it out.
  def registrant_ids_by(field)
    registrant_id_maps[field] ||= group_registrant_ids(rows.select { |row| row.public_send(field).present? }, &field)
  end

  # US states only, so regions abroad stay off the States map.
  def registrant_ids_by_state
    @registrant_ids_by_state ||= group_registrant_ids(rows.select { |row| Address::US_STATE_ABBREVIATIONS.include?(row.state.to_s.upcase) }, &:state)
  end

  def registrant_ids_by_city_label
    @registrant_ids_by_city_label ||= group_registrant_ids(rows.select(&:city_label), &:city_label)
  end

  # Distinct values of one or more location fields across every address these
  # people could resolve to — their affiliated organizations' and their own — for
  # a filter's option list. Two grouped queries rather than a row per person, so
  # the attendees index can offer options drawn from its whole reportable
  # population. It skips the work-else-home precedence #rows applies, so it can
  # offer a value no one settles on; an option list is already deliberately wider
  # than the active filters.
  def candidate_values(*fields)
    [ organization_addresses, person_addresses ].flat_map { |scope|
      fields.reduce(scope) { |relation, field| relation.where.not(field => [ nil, "" ]) }.distinct.pluck(*fields)
    }.uniq.sort
  end

  private

  def matches?(row, field, value, searched: SEARCHED_FIELDS.include?(field))
    actual = row.public_send(field).to_s
    return actual.downcase.include?(value.to_s.downcase.strip) if searched
    actual.casecmp?(value.to_s)
  end

  def registrant_id_maps
    @registrant_id_maps ||= {}
  end

  def group_registrant_ids(rows, &key)
    rows.group_by(&key).transform_values { |grouped| grouped.map(&:registrant_id).uniq }
  end

  def row(organization_id, registrant_id, address)
    Row.new(organization_id:, registrant_id:, **LOCATION_FIELDS.index_with { |field| address&.public_send(field) })
  end

  def affiliations
    scope = @on ? Affiliation.active_by_date_on(@on) : Affiliation.active
    scope.where(person_id: @person_ids)
  end

  def affiliation_triples
    @affiliation_triples ||= affiliations.distinct.pluck(:person_id, :organization_id, :organization_address_id)
  end

  def chosen_addresses
    @chosen_addresses ||= Address.active
      .where(id: affiliations.select(:organization_address_id))
      .select(:id, *LOCATION_FIELDS)
      .index_by(&:id)
  end

  def organization_addresses
    Address.active.where(addressable_type: "Organization", addressable_id: affiliations.select(:organization_id))
  end

  # Not narrowed to active: a person with nothing but a retired address is better
  # placed there than left out of the map entirely (Address#ranked_for_owner ranks
  # retired addresses last).
  def person_addresses
    Address.where(addressable_type: "Person", addressable_id: @person_ids)
  end

  def oldest_address_by_organization
    @oldest_address_by_organization ||= organization_addresses
      .order(:id)
      .select(:id, :addressable_id, *LOCATION_FIELDS)
      .each_with_object({}) { |address, map| map[address.addressable_id] ||= address }
  end

  def own_address_by_person
    @own_address_by_person ||= person_addresses
      .ranked_for_owner
      .select(:id, :addressable_id, :inactive, :address_type, :updated_at, *LOCATION_FIELDS)
      .each_with_object({}) { |address, map| map[address.addressable_id] ||= address }
  end
end
