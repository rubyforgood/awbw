# One spelling per country, so "US", "USA" and "United States" count as the same place.
module CountryName
  UNITED_STATES = "United States"
  US_MINOR_OUTLYING_ISLANDS = "United States Minor Outlying Islands"
  BLANK_HINT = "If blank, we'll use the state"
  # Typed in place of a country to say there isn't one, keyed as AddressNormalizer.words joins them.
  PLACEHOLDERS = [ "n a", "none", "unknown", "not applicable" ].to_set.freeze

  # Spellings found in AWBW's data (form answers + FileMaker) that the countries gem doesn't read.
  ALIASES = {
    "unites states" => UNITED_STATES, "untied states" => UNITED_STATES,
    "los angeles" => UNITED_STATES, "la county" => UNITED_STATES,
    "us minor outlying islands" => UNITED_STATES, US_MINOR_OUTLYING_ISLANDS.downcase => UNITED_STATES,
    "korea" => "South Korea", "republic of ireland" => "Ireland", "mexcio" => "Mexico",
    "scotland" => "United Kingdom", "republic of armenia" => "Armenia"
  }.freeze

  # Provinces and regions written in an address's state field, keyed as AddressNormalizer.words joins them.
  REGIONS = {
    "Canada" => [ "on", "ontario", "bc", "british columbia", "ab", "alberta", "ns", "nova scotia", "qc", "quebec",
                  "mb", "manitoba", "sk", "saskatchewan", "nb", "new brunswick", "nl", "newfoundland",
                  "newfoundland and labrador", "pe", "pei", "prince edward island", "yt", "yukon", "nu", "nunavut",
                  "northwest territories" ],
    "Australia" => [ "nsw", "new south wales", "vic", "victoria", "qld", "queensland", "tas", "tasmania",
                     "south australia", "western australia" ],
    "United Kingdom" => [ "england", "scotland", "wales", "northern ireland", "london", "bucks", "buckinghamshire",
                          "somerset", "argyle and bute", "argyll and bute" ],
    "Vietnam" => [ "ha noi", "hanoi" ],
    "Mexico" => [ "mexico city", "cdmx" ],
    "Japan" => [ "tokyo" ],
    "Philippines" => [ "metro manila" ],
    "Ghana" => [ "greater accra" ],
    "Trinidad and Tobago" => [ "trinidad", "tobago" ]
  }.flat_map { |country, regions| regions.map { |region| [ region, country ] } }.to_h.freeze

  # A US state name anywhere in the value, so "CA - California" and "Maryland (MD)" read as US.
  US_STATE_NAME = /\b(#{AddressNormalizer::STATE_NAMES.keys.map { |name| Regexp.escape(name) }.join("|")})\b/

  module_function

  # Dropdown choices: the United States first, then every other country A–Z.
  def options
    @options ||= [ UNITED_STATES ] +
      (ISO3166::Country.all.map(&:common_name) - [ UNITED_STATES, US_MINOR_OUTLYING_ISLANDS ]).sort
  end

  # The common name for a typed country or ISO code, or nil when it isn't recognized.
  def canonical(value)
    text = value.to_s.strip
    return if text.blank?
    return ALIASES[text.downcase] if ALIASES.key?(text.downcase)
    return UNITED_STATES if AddressNormalizer::US_COUNTRY_NAMES.include?(text.downcase.delete("^a-z"))

    country = ISO3166::Country.find_country_by_alpha2(text) ||
      ISO3166::Country.find_country_by_alpha3(text) ||
      ISO3166::Country.find_country_by_any_name(text)
    country&.common_name
  end

  # An address's country: the typed one when recognized, else the one its state implies,
  # else the typed value as-is. A placeholder ("-", "n/a", "unknown") is no country, and a
  # US state code typed as the country ("CA" next to state CA) is the US, not Canada.
  def resolve(country, state:)
    text = country.to_s.strip
    text = "" if placeholder?(text)
    return UNITED_STATES if us_state?(text) && us_state?(state)

    canonical(text) || from_state(state) || text.presence
  end

  # The country a state implies: a US state, a known province or region, or a
  # country named as the state ("England", "Togo").
  def from_state(state)
    return UNITED_STATES if us_state?(state)

    key = AddressNormalizer.words(state).join(" ")
    return if key.blank?

    REGIONS[key] || ISO3166::Country.find_country_by_any_name(state.to_s.strip)&.common_name
  end

  def placeholder?(text)
    !text.match?(/[[:alpha:]]/) || PLACEHOLDERS.include?(AddressNormalizer.words(text).join(" "))
  end

  # "CA", "Ca.", "California", "VIRGINIA", "CA - California" are US states; "ON", "BC" aren't.
  def us_state?(state)
    AddressNormalizer::US_STATES.include?(AddressNormalizer.state(state)) ||
      AddressNormalizer.words(state).join(" ").match?(US_STATE_NAME)
  end
end
