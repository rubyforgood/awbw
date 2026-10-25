# Where registrants work, per registration: each organization linked on the
# registration, at the address picked on the registration's affiliation with it
# (Affiliation#organization_address), else that org's oldest active address. The
# source for the registrant charts' and filters' cities, counties, states, and
# countries. A linked org with no active address still yields a row, with no
# location, so the cities breakdown can count it as Unknown.
class RegistrationWorkAddresses
  Row = Struct.new(:registration_id, :organization_id, :registrant_id, :city, :county, :state, :country, keyword_init: true) do
    def city_label
      [ city, state ].compact_blank.join(", ").presence
    end
  end

  def initialize(registration_ids)
    @registration_ids = registration_ids
  end

  def rows
    @rows ||= links.map do |registration_id, organization_id, registrant_id|
      address = chosen_addresses[chosen_address_ids[[ registration_id, organization_id ]]] ||
        oldest_address_by_organization[organization_id]
      Row.new(registration_id:, organization_id:, registrant_id:,
              city: address&.city, county: address&.county, state: address&.state, country: address&.country)
    end
  end

  # Rows whose one address matches every given part: state and county exactly,
  # city as a case-insensitive substring.
  def matching(state: nil, county: nil, city: nil)
    term = city.to_s.downcase.strip.presence
    rows.select do |row|
      (state.blank? || row.state == state) &&
        (county.blank? || row.county == county) &&
        (term.nil? || row.city.to_s.downcase.include?(term))
    end
  end

  def rows_by_registration
    @rows_by_registration ||= rows.group_by(&:registration_id)
  end

  # Distinct [ state, county ] pairs, sorted, for the County filters.
  def counties
    @counties ||= rows.filter_map { |row| [ row.state, row.county ] if row.state.present? && row.county.present? }.uniq.sort
  end

  # US states only, so regions abroad stay off the States map.
  def registrant_ids_by_state
    @registrant_ids_by_state ||= registrant_ids_by(rows.select { |row| Address::US_STATE_ABBREVIATIONS.include?(row.state.to_s.upcase) }, &:state)
  end

  def registrant_ids_by_country
    @registrant_ids_by_country ||= registrant_ids_by(rows.select { |row| row.country.present? }, &:country)
  end

  def registrant_ids_by_city_label
    @registrant_ids_by_city_label ||= registrant_ids_by(rows.select(&:city_label), &:city_label)
  end

  private

  def registrant_ids_by(rows, &key)
    rows.group_by(&key).transform_values { |grouped| grouped.map(&:registrant_id).uniq }
  end

  def links
    @links ||= EventRegistrationOrganization
      .joins(:event_registration)
      .where(event_registration_id: @registration_ids)
      .pluck(:event_registration_id, :organization_id, Arel.sql("event_registrations.registrant_id"))
  end

  def chosen_address_ids
    @chosen_address_ids ||= Affiliation
      .where(event_registration_id: @registration_ids)
      .where.not(organization_address_id: nil)
      .pluck(:event_registration_id, :organization_id, :organization_address_id)
      .to_h { |registration_id, organization_id, address_id| [ [ registration_id, organization_id ], address_id ] }
  end

  def chosen_addresses
    @chosen_addresses ||= Address.active.where(id: chosen_address_ids.values.uniq).select(:id, :city, :county, :state, :country).index_by(&:id)
  end

  def oldest_address_by_organization
    @oldest_address_by_organization ||= Address.active
      .where(addressable_type: "Organization", addressable_id: links.map(&:second).uniq)
      .order(:id)
      .select(:id, :addressable_id, :city, :county, :state, :country)
      .each_with_object({}) { |address, map| map[address.addressable_id] ||= address }
  end
end
