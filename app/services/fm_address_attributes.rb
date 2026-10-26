# Turns an FmAddress row's fields into Address attributes — state, country, type and
# locality translated as the dropdowns store them (ADR-0009) — or nil when the row lacks the
# city or state an address needs. One instance serves a whole import: the archive's
# ZIP table is read once, and #unmatched gathers every value it couldn't translate.
class FmAddressAttributes
  STRING_LIMIT = 255

  # The address an addressable already holds for a row: the same street in the same city, or,
  # for a row with no street, any address in that city.
  def self.held(addresses, attributes)
    city = AddressNormalizer.city(attributes[:city])
    street = AddressNormalizer.street(attributes[:street_address])
    addresses.find do |address|
      AddressNormalizer.city(address.city) == city && (street.empty? || AddressNormalizer.street(address.street_address) == street)
    end
  end

  def initialize
    @translation = AddressTranslation.new
  end

  def unmatched = @translation.unmatched

  # An organization's address is always work; the one the archive calls mailing is its invoice address.
  def call(fields, organization: false)
    street = [ street_line(fields), fields["AddrsLine2"] ].filter_map { |line| line.to_s.strip.presence }.join(", ")
    city = clip(fields["AddrsCity"].to_s.strip)
    state = clip(fields["AddrsState"].to_s.strip)
    return if city.blank? || state.blank?

    @translation.address(
      street_address: street.truncate(STRING_LIMIT),
      city:,
      state:,
      zip_code: zip_code(fields),
      country: clip(fields["AddrsCountry"]),
      county: county(fields),
      address_type: fields["AddrsType"]
    ).then { |attributes| organization ? organization_address(attributes) : attributes }
  end

  # An address holding just a city and state — where the archive records a place (a
  # project's city) with no street — translated the same way.
  def place(city:, state:, county: nil)
    @translation.address(street_address: "", zip_code: "", city: clip(city), state: clip(state), country: nil,
                         county: clip(county), address_type: nil)
  end

  private

  def organization_address(attributes)
    attributes.merge(address_type: "work", invoice_address: attributes[:address_type] == "mailing")
  end

  # The house number has its own field, sometimes already repeated at the front of
  # the first line.
  def street_line(fields)
    number = fields["StreetNo"].to_s.strip
    line = fields["AddrsLine1"].to_s.strip
    return line if number.blank? || line[/\A\S+/] == number

    "#{number} #{line}".strip
  end

  # The address's own postal code, or the one it points at in the archive's ZIP table
  # when it carries none itself — the field it mirrors, and where the county is read.
  def zip_code(fields)
    [ fields["AddrsPostalCode"], fields["PostalCodeLookup"] ]
      .filter_map { |value| value.to_s.strip.presence }.first.to_s.truncate(STRING_LIMIT)
  end

  def county(fields)
    zip_counties[zip_lookup(fields)[/\A\d{5}/]]
  end

  def zip_lookup(fields)
    (fields["PostalCodeLookup"].presence || fields["AddrsPostalCode"]).to_s.strip
  end

  # One query for the archive's ~80,000 zip codes beats one per address across a full import.
  def zip_counties
    @zip_counties ||= FmPostalCode.pluck(:fm_id, Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(data, '$.County'))"))
                                  .to_h { |zip, county| [ zip, clip(county) ] }
  end

  # The archive's free text isn't bounded by the varchar(255) it lands in.
  def clip(value)
    value.presence && value.to_s.truncate(STRING_LIMIT)
  end
end
