# The country, county and locality an address leaves blank, worked out from its other parts: a
# US state means the United States, a US ZIP gives the county, and AddressLocality the locality.
# The locality comes back Unknown when the parts don't settle it.
module AddressDefaults
  module_function

  def for(city:, state:, zip_code: nil, country: nil, county: nil)
    country = country.presence || (Address::DEFAULT_COUNTRY if us_state?(state))
    county = county.presence || (FmPostalCode.county_for(zip_code, state:) unless AddressLocality.outside_usa?(state, country))
    { country:, county:, locality: AddressLocality.for(city:, state:, country:, county:) }
  end

  def us_state?(state)
    AddressNormalizer.country(nil, in_state: state) == AddressNormalizer::US_COUNTRY
  end
end
