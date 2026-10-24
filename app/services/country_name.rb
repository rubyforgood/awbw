# One spelling per country, so "US", "USA" and "United States" count as the same place.
module CountryName
  UNITED_STATES = "United States"

  module_function

  # Dropdown choices: the United States first, then every other country A–Z.
  def options
    @options ||= [ UNITED_STATES ] + (ISO3166::Country.all.map(&:common_name) - [ UNITED_STATES ]).sort
  end

  # The common name for a typed country or ISO code, or nil when it isn't recognized.
  def canonical(value)
    text = value.to_s.strip
    return if text.blank?
    return UNITED_STATES if AddressNormalizer::US_COUNTRY_NAMES.include?(text.downcase.delete("^a-z"))

    country = ISO3166::Country.find_country_by_alpha2(text) ||
      ISO3166::Country.find_country_by_alpha3(text) ||
      ISO3166::Country.find_country_by_any_name(text)
    country&.common_name
  end
end
