# Turns an FmAddress row's fields into Address attributes, or nil when the row lacks the
# street, city or state an address needs. One instance serves a whole import: the
# archive's ZIP table is read once, the first time a county is looked up.
class FmAddressAttributes
  include FilemakerValues

  def call(fields, address_type: nil)
    street = [ street_line(fields), fields["AddrsLine2"] ].filter_map { |line| line.to_s.strip.presence }.join(", ")
    city = clip(fields["AddrsCity"].to_s.strip)
    state = clip(fields["AddrsState"].to_s.strip)
    return if street.blank? || city.blank? || state.blank?

    country = clip(fields["AddrsCountry"])
    county = county(fields)
    {
      street_address: clip(street),
      city:,
      state:,
      zip_code: zip_code(fields),
      country:,
      county:,
      address_type: address_type || contact_type(fields["AddrsType"], allowed: Address::CONTACT_TYPES),
      locality: AddressLocality.for(city:, state:, country:, county:)
    }
  end

  private

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
end
