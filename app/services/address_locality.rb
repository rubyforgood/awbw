# Which of AWBW's localities an address falls in, worked out from its own parts, for an
# import or a submitted form that has an address but never asked the question. FileMaker
# records a Locality only on a project (so the organizations pass carries it across);
# nothing records one for a person's home address.
#
# Only the calls the parts settle are made. The Northern/Central/Southern line through
# California is AWBW's own and nothing says where it runs, so a California address outside
# Los Angeles and Orange counties stays Unknown for a person to choose — as does an address
# whose state is a spelling no US state answers to, since a typo and a foreign region read
# alike.
module AddressLocality
  module_function

  CALIFORNIA = "ca"
  LOS_ANGELES = "los angeles"
  ORANGE = "orange"

  def for(city:, state:, country: nil, county: nil)
    return Address::OUTSIDE_USA if outside_usa?(state, country)

    state = AddressNormalizer.state(state)
    return Address::UNKNOWN_LOCALITY unless AddressNormalizer::US_STATES.include?(state)
    return Address::OUTSIDE_CA unless state == CALIFORNIA

    in_california(city, county)
  end

  # A country the address names that isn't the US. A blank country on a US state is the US
  # (AddressNormalizer#country), and a blank one anywhere else says nothing either way.
  def outside_usa?(state, country)
    country = AddressNormalizer.country(country, in_state: state)
    country.present? && country != AddressNormalizer::US_COUNTRY
  end

  # LA City sits inside LA County, so the county alone only settles the broader one — and
  # a Los Angeles mailing city settles the city whether or not the county came through.
  def in_california(city, county)
    county = AddressNormalizer.county(county)
    return Address::LA_CITY if AddressNormalizer.city(city) == LOS_ANGELES
    return Address::LA_COUNTY if county == LOS_ANGELES
    return Address::ORANGE_COUNTY if county == ORANGE

    Address::UNKNOWN_LOCALITY
  end
end
