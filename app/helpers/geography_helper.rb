module GeographyHelper
  def us_states
    UsState::ALL
  end

  # A <datalist> of US states for a free-text state/region input: it suggests US
  # states (stored as abbreviations) while still letting the user type any
  # international region or leave it blank. Reference it from an input via
  # `list:` matching the given +id+.
  def us_states_datalist(id)
    options = us_states.map { |name, abbr| tag.option(value: abbr, label: name) }
    tag.datalist(safe_join(options), id: id)
  end

  # Country names for the address country dropdown: the canonical "United States"
  # first (it drives the US-state-vs-region toggle), then every other country
  # alphabetically. The US is excluded from the gem list by code so the only US
  # option is our canonical value, not the gem's verbose "United States of America".
  def country_options
    others = ISO3166::Country.all
      .reject { |country| country.alpha2 == "US" }
      .map(&:iso_short_name)
      .sort
    [ Address::US_COUNTRY ] + others
  end
end
