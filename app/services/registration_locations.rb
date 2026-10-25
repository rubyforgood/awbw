# Where each registrant is, per registration — where they work, else where they
# live: each organization linked on the registration, at the address picked on
# the registration's affiliation with it (Affiliation#organization_address), else
# that org's oldest active address; with no such address, the one address that
# stands for the registrant themselves (Address#ranked_for_owner — active work,
# else latest-edited active personal, else inactive personal, else inactive work).
# The source for every registrant location
# chart, count, and filter. A linked org with no address and no own address to
# fall back on yields a row with no location, so the cities breakdown can count
# it as Unknown.
class RegistrationLocations
  # Everything an address says about *where* it is — the whole record bar the
  # street and phone, which identify a building rather than place it. A row
  # carries all of them so a new chart, count, or filter needs only a field name.
  LOCATION_FIELDS = %i[
    city county state country locality zip_code district
    la_city_council_district la_supervisorial_district la_service_planning_area
  ].freeze
  # Fields a filter matches on a case-insensitive substring, because they arrive
  # from a free-text box. The rest are picked from a list this class built, so
  # they match whole (case-insensitively, as the database's own collation does).
  # Add a field here when it gets a text box of its own.
  SEARCHED_FIELDS = %i[ city ].freeze
  # County filter options carry their state so same-named counties across states
  # don't collide — "CA|Los Angeles" on the registrants roster, "CA::Los Angeles"
  # on the attendees index.
  COUNTY_STATE_SEPARATOR = /::|\|/

  Row = Struct.new(:registration_id, :organization_id, :registrant_id, *LOCATION_FIELDS, keyword_init: true) do
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

  # Takes the registrations to locate, as a relation (kept as a subquery, so a
  # whole-population lookup never inlines every id) or as an explicit id array.
  def initialize(registrations)
    @registrations = if registrations.is_a?(ActiveRecord::Relation)
      registrations.except(:includes, :eager_load, :preload, :order, :select, :limit, :offset)
    else
      EventRegistration.where(id: registrations)
    end
  end

  def rows
    @rows ||= registration_pairs.flat_map do |registration_id, registrant_id|
      located = organization_ids_by_registration.fetch(registration_id, []).map do |organization_id|
        [ organization_id, chosen_addresses[chosen_address_ids[[ registration_id, organization_id ]]] || oldest_address_by_organization[organization_id] ]
      end
      located = [ [ nil, own_address_by_person[registrant_id] ] ] if located.none?(&:last) && own_address_by_person[registrant_id]
      located.map { |organization_id, address| row(registration_id, organization_id, registrant_id, address) }
    end
  end

  # Rows whose one address answers to every field given — so a registrant working
  # in two states can't match a city from one and the county from the other. Pass
  # the whole filter set in one call; chaining two calls is what loses that.
  def matching(**filters)
    filters = filters.compact_blank
    filters.assert_valid_keys(*LOCATION_FIELDS)
    rows.select { |row| filters.all? { |field, value| matches?(row, field, value) } }
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
  # registrations could resolve to — the linked organizations' and the
  # registrants' own — for a filter's option list. Two grouped queries rather
  # than a row per registration, so the attendees index can offer options drawn
  # from its whole reportable population. It skips the work-else-home precedence
  # #rows applies, so it can offer a value no registration settles on; an option
  # list is already deliberately wider than the active filters.
  def candidate_values(*fields)
    [ organization_addresses, registrant_addresses ].flat_map { |scope|
      fields.reduce(scope) { |relation, field| relation.where.not(field => [ nil, "" ]) }.distinct.pluck(*fields)
    }.uniq.sort
  end

  private

  def matches?(row, field, value)
    actual = row.public_send(field).to_s
    return actual.downcase.include?(value.to_s.downcase.strip) if SEARCHED_FIELDS.include?(field)
    actual.casecmp?(value.to_s)
  end

  def registrant_id_maps
    @registrant_id_maps ||= {}
  end

  def group_registrant_ids(rows, &key)
    rows.group_by(&key).transform_values { |grouped| grouped.map(&:registrant_id).uniq }
  end

  def row(registration_id, organization_id, registrant_id, address)
    Row.new(registration_id:, organization_id:, registrant_id:,
            **LOCATION_FIELDS.index_with { |field| address&.public_send(field) })
  end

  def registration_pairs
    @registration_pairs ||= @registrations.pluck(:id, :registrant_id)
  end

  def registration_ids
    @registrations.select(:id)
  end

  def organization_ids_by_registration
    @organization_ids_by_registration ||= EventRegistrationOrganization
      .where(event_registration_id: registration_ids)
      .pluck(:event_registration_id, :organization_id)
      .group_by(&:first)
      .transform_values { |pairs| pairs.map(&:last) }
  end

  def chosen_address_ids
    @chosen_address_ids ||= Affiliation
      .where(event_registration_id: registration_ids)
      .where.not(organization_address_id: nil)
      .pluck(:event_registration_id, :organization_id, :organization_address_id)
      .to_h { |registration_id, organization_id, address_id| [ [ registration_id, organization_id ], address_id ] }
  end

  def chosen_addresses
    @chosen_addresses ||= Address.active
      .where(id: Affiliation.where(event_registration_id: registration_ids).select(:organization_address_id))
      .select(:id, *LOCATION_FIELDS)
      .index_by(&:id)
  end

  def organization_addresses
    Address.active.where(addressable_type: "Organization",
                         addressable_id: EventRegistrationOrganization.where(event_registration_id: registration_ids).select(:organization_id))
  end

  # Not narrowed to active: a registrant with nothing but a retired address is
  # better placed there than left out of the map entirely (Address#ranked_for_owner
  # ranks retired addresses last).
  def registrant_addresses
    Address.where(addressable_type: "Person", addressable_id: @registrations.select(:registrant_id))
  end

  def oldest_address_by_organization
    @oldest_address_by_organization ||= organization_addresses
      .order(:id)
      .select(:id, :addressable_id, *LOCATION_FIELDS)
      .each_with_object({}) { |address, map| map[address.addressable_id] ||= address }
  end

  def own_address_by_person
    @own_address_by_person ||= registrant_addresses
      .ranked_for_owner
      .select(:id, :addressable_id, :inactive, :address_type, :updated_at, *LOCATION_FIELDS)
      .each_with_object({}) { |address, map| map[address.addressable_id] ||= address }
  end
end
