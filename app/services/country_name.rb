# One spelling per country, so "US", "USA" and "United States" count as the same place.
module CountryName
  UNITED_STATES = "United States"
  US_MINOR_OUTLYING_ISLANDS = "United States Minor Outlying Islands"
  BLANK_HINT = "If blank, we'll use the state"
  # Typed in place of a country to say there isn't one, keyed as AddressNormalizer.words joins them.
  PLACEHOLDERS = [ "n a", "none", "unknown", "not applicable" ].to_set.freeze

  # Everyday names for countries whose ISO name reads formally, keyed by ISO code.
  PLAIN_NAMES = {
    "RU" => "Russia", "SY" => "Syria", "LA" => "Laos", "BN" => "Brunei", "VA" => "Vatican City",
    "FM" => "Micronesia", "PS" => "Palestine", "CD" => "Democratic Republic of the Congo",
    "CG" => "Republic of the Congo", "VG" => "British Virgin Islands", "VI" => "U.S. Virgin Islands",
    "BQ" => "Caribbean Netherlands", "CC" => "Cocos Islands", "FK" => "Falkland Islands",
    "MF" => "Saint Martin", "SX" => "Sint Maarten", "SH" => "Saint Helena"
  }.freeze

  # Spellings found in AWBW's data (form answers + FileMaker) that the countries gem doesn't read, by ISO code.
  ALIASES = {
    "unites states" => "US", "untied states" => "US", "los angeles" => "US", "la county" => "US",
    "us minor outlying islands" => "US", US_MINOR_OUTLYING_ISLANDS.downcase => "US",
    "korea" => "KR", "republic of ireland" => "IE", "mexcio" => "MX", "scotland" => "GB", "republic of armenia" => "AM"
  }.merge(PLAIN_NAMES.to_h { |code, name| [ name.downcase, code ] }).freeze

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
      (ISO3166::Country.all.map { |country| name_for(country) } - [ UNITED_STATES, US_MINOR_OUTLYING_ISLANDS ]).sort
  end

  # The stored country to preselect: its plain name, or the value as stored when unrecognized.
  def selected(current)
    canonical(current) || current.to_s.strip.presence
  end

  # The options plus an unrecognized stored value, so opening and saving a form keeps it.
  def options_for(current)
    value = selected(current)
    value.nil? || options.include?(value) ? options : options + [ value ]
  end

  # The gem's country for a typed name, plain name, alias, or ISO code.
  def find(value)
    text = value.to_s.strip
    return if text.blank?

    code = ALIASES[text.downcase]
    code ||= "US" if AddressNormalizer::US_COUNTRY_NAMES.include?(text.downcase.delete("^a-z"))
    return ISO3166::Country.new(code) if code

    ISO3166::Country.find_country_by_alpha2(text) ||
      ISO3166::Country.find_country_by_alpha3(text) ||
      ISO3166::Country.find_country_by_any_name(text)
  end

  # The plain name for a typed country or ISO code, or nil when it isn't recognized.
  def canonical(value)
    country = find(value)
    name_for(country) if country
  end

  def name_for(country)
    PLAIN_NAMES[country.alpha2] || country.common_name
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

    return REGIONS[key] if REGIONS.key?(key)

    country = ISO3166::Country.find_country_by_any_name(state.to_s.strip)
    name_for(country) if country
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
