# Which of AWBW's localities an address falls in, worked out from its own parts, for an
# import or a submitted form that has an address but never asked the question. FileMaker
# records a Locality only on a project (so the organizations pass carries it across);
# nothing records one for a person's home address.
#
# Only the calls the parts settle are made. A California address with no county, or one in a
# county no region is recorded for, stays Unknown for a person to choose — as does an address
# whose state is a spelling no US state answers to, since a typo and a foreign region read
# alike.
module AddressLocality
  module_function

  CALIFORNIA = "ca"
  LOS_ANGELES = "los angeles"
  ORANGE = "orange"

  # Mailing cities that are neighborhoods inside the City of Los Angeles.
  LA_CITY_NEIGHBORHOODS = [
    "canoga park", "north hollywood", "pacific palisades", "pacoima", "san pedro", "sherman oaks",
    "sylmar", "van nuys", "venice", "winnetka"
  ].to_set.freeze

  # AWBW's Northern/Central/Southern line: the region most FileMaker projects in each county name,
  # plus a hand-checked few no project placed.
  CALIFORNIA_REGIONS = {
    "Northern CA" => [
      "alameda", "amador", "butte", "calaveras", "colusa", "contra costa", "del norte", "el dorado",
      "humboldt", "lake", "lassen", "marin", "mendocino", "merced", "modoc", "monterey", "napa", "nevada",
      "placer", "plumas", "sacramento", "san francisco", "san joaquin", "san mateo", "santa clara",
      "santa cruz", "shasta", "siskiyou", "solano", "sonoma", "sutter", "tehama", "trinity", "tuolumne",
      "yolo", "yuba"
    ],
    "Central CA" => [
      "fresno", "inyo", "kern", "kings", "madera", "mariposa", "mono", "san benito", "san luis obispo",
      "stanislaus", "tulare"
    ],
    "Southern CA" => [ "imperial", "riverside", "san bernardino", "san diego", "santa barbara", "ventura" ]
  }.flat_map { |region, counties| counties.map { |county| [ county, region ] } }.to_h.freeze

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
    city = AddressNormalizer.city(city)
    return Address::LA_CITY if city == LOS_ANGELES || LA_CITY_NEIGHBORHOODS.include?(city)
    return Address::LA_COUNTY if county == LOS_ANGELES
    return Address::ORANGE_COUNTY if county == ORANGE

    CALIFORNIA_REGIONS.fetch(county, Address::UNKNOWN_LOCALITY)
  end
end
