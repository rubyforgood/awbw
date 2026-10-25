# Turns the address values other systems and older free-text forms wrote — FileMaker, the
# LMS registration sheet, the portal's own answers from before the dropdowns — into what the
# portal's address dropdowns store (ADR-0009). Translation is by lookup table, never guessed:
# a country nothing answers to is cleared so every stored country is a dropdown one, and
# counted in #unmatched with the state values it can't read.
#
# Built once per run and reused, so an import's report can list everything it couldn't place.
class AddressTranslation
  UNITED_STATES = "United States"

  # The words the archive and the forms use for a kind of address, phone, or email.
  CONTACT_TYPES = { "home" => "personal", "personal" => "personal", "cell" => "personal",
                    "mobile" => "personal", "work" => "work", "business" => "work",
                    "professional" => "work", "mailing" => "mailing" }.freeze

  # Spellings found in our data that the countries gem doesn't read, by ISO code. A US city
  # or county typed as the country is the US; the outlying islands aren't on the dropdown.
  ALIASES = {
    "unites states" => "US", "untied states" => "US", "los angeles" => "US", "la county" => "US",
    "us minor outlying islands" => "US", "united states minor outlying islands" => "US",
    "korea" => "KR", "republic of ireland" => "IE", "mexcio" => "MX", "scotland" => "GB", "republic of armenia" => "AM"
  }.merge(GeographyHelper::PLAIN_COUNTRY_NAMES.to_h { |code, name| [ name.downcase, code ] }).freeze

  # Provinces and regions written in the state field, keyed as AddressNormalizer.words joins them.
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

  # Typed in place of a country to say there isn't one, keyed as AddressNormalizer.words joins them.
  PLACEHOLDERS = [ "n a", "none", "unknown", "not applicable" ].to_set.freeze

  # A US state's full name anywhere in the value, so "CA - California" and "Maryland (MD)" read as a state.
  US_STATE_NAME = /\b(#{AddressNormalizer::STATE_NAMES.keys.map { |name| Regexp.escape(name) }.join("|")})\b/

  attr_reader :unmatched

  def initialize
    @unmatched = Hash.new { |hash, field| hash[field] = Hash.new(0) }
  end

  # A dropdown country: the one the value names, else the one its state implies, else nil
  # (reported when there was a value to read).
  def country(value, state:)
    text = value.to_s.strip
    text = "" if placeholder?(text)
    return UNITED_STATES if us_state_code(text) && us_state_code(state)

    found = country_named(text) || country_from_state(state)
    @unmatched[:country][text] += 1 if found.nil? && text.present?
    found
  end

  # A US state's USPS code; any other region as typed. A value that reads as neither, on an
  # address in the US or with no country, is reported.
  def state(value, country:)
    text = value.to_s.strip
    return if text.blank?

    abroad = country_named(country.to_s.strip).then { |named| named.present? && named != UNITED_STATES }
    return text if abroad

    code = us_state_code(text)
    return code.upcase if code

    @unmatched[:state][text] += 1 unless country_from_state(text)
    text
  end

  def address_type(value)
    CONTACT_TYPES[value.to_s.strip.downcase].presence_in(Address::CONTACT_TYPES)
  end

  def locality(city:, state:, country:, county: nil)
    AddressLocality.for(city:, state:, country:, county:)
  end

  # Address attributes with their state, country, and type translated and a locality worked out.
  def address(attributes)
    state = state(attributes[:state], country: attributes[:country])
    country = country(attributes[:country], state: attributes[:state])
    attributes.merge(state:, country:, address_type: address_type(attributes[:address_type]),
                     locality: locality(city: attributes[:city], state:, country:, county: attributes[:county]))
  end

  private

  def country_named(text)
    return if text.blank?

    code = ALIASES[text.downcase]
    code ||= "US" if AddressNormalizer::US_COUNTRY_NAMES.include?(text.downcase.delete("^a-z"))
    found = code ? ISO3166::Country.new(code) : gem_country(text)
    name_for(found) if found
  end

  def gem_country(text)
    ISO3166::Country.find_country_by_alpha2(text) ||
      ISO3166::Country.find_country_by_alpha3(text) ||
      ISO3166::Country.find_country_by_any_name(text)
  end

  # A US state, a known province or region, or a country named as the state ("England", "Togo").
  def country_from_state(state)
    return UNITED_STATES if us_state_code(state)

    key = AddressNormalizer.words(state).join(" ")
    return if key.blank?
    return REGIONS[key] if REGIONS.key?(key)

    found = ISO3166::Country.find_country_by_any_name(state.to_s.strip)
    name_for(found) if found
  end

  def name_for(country)
    return UNITED_STATES if ALIASES[country.common_name.downcase] == "US"

    GeographyHelper::PLAIN_COUNTRY_NAMES[country.alpha2] || country.common_name
  end

  # The lowercase USPS code a value names, or nil: "CA", "Ca.", "California", "CA - California".
  def us_state_code(value)
    code = AddressNormalizer.state(value)
    return code if AddressNormalizer::US_STATES.include?(code)

    name = AddressNormalizer.words(value).join(" ")[US_STATE_NAME]
    AddressNormalizer::STATE_NAMES[name] if name
  end

  def placeholder?(text)
    !text.match?(/[[:alpha:]]/) || PLACEHOLDERS.include?(AddressNormalizer.words(text).join(" "))
  end
end
