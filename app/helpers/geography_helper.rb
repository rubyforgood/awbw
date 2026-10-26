module GeographyHelper
  def us_states
    [
      [ "Alabama", "AL" ],
      [ "Alaska", "AK" ],
      [ "American Samoa", "AS" ],
      [ "Arizona", "AZ" ],
      [ "Arkansas", "AR" ],
      [ "California", "CA" ],
      [ "Colorado", "CO" ],
      [ "Connecticut", "CT" ],
      [ "Delaware", "DE" ],
      [ "District of Columbia", "DC" ],
      [ "Florida", "FL" ],
      [ "Georgia", "GA" ],
      [ "Guam", "GU" ],
      [ "Hawaii", "HI" ],
      [ "Idaho", "ID" ],
      [ "Illinois", "IL" ],
      [ "Indiana", "IN" ],
      [ "Iowa", "IA" ],
      [ "Kansas", "KS" ],
      [ "Kentucky", "KY" ],
      [ "Louisiana", "LA" ],
      [ "Maine", "ME" ],
      [ "Maryland", "MD" ],
      [ "Massachusetts", "MA" ],
      [ "Michigan", "MI" ],
      [ "Minnesota", "MN" ],
      [ "Mississippi", "MS" ],
      [ "Missouri", "MO" ],
      [ "Montana", "MT" ],
      [ "Nebraska", "NE" ],
      [ "Nevada", "NV" ],
      [ "New Hampshire", "NH" ],
      [ "New Jersey", "NJ" ],
      [ "New Mexico", "NM" ],
      [ "New York", "NY" ],
      [ "North Carolina", "NC" ],
      [ "North Dakota", "ND" ],
      [ "Northern Mariana Islands", "MP" ],
      [ "Ohio", "OH" ],
      [ "Oklahoma", "OK" ],
      [ "Oregon", "OR" ],
      [ "Pennsylvania", "PA" ],
      [ "Puerto Rico", "PR" ],
      [ "Rhode Island", "RI" ],
      [ "South Carolina", "SC" ],
      [ "South Dakota", "SD" ],
      [ "Tennessee", "TN" ],
      [ "Texas", "TX" ],
      [ "U.S. Virgin Islands", "VI" ],
      [ "Utah", "UT" ],
      [ "Vermont", "VT" ],
      [ "Virginia", "VA" ],
      [ "Washington", "WA" ],
      [ "West Virginia", "WV" ],
      [ "Wisconsin", "WI" ],
      [ "Wyoming", "WY" ]
    ]
  end

  def us_state?(abbreviation)
    us_states.any? { |_name, abbr| abbr == abbreviation }
  end

  # A saved state the US-state dropdown can't show, which belongs in the "Not on list?" box.
  def outside_usa_state?(state)
    state.present? && !us_state?(state)
  end

  # State dropdown options that always include the address's current value, even
  # when it isn't a US state (e.g. an international province like "ON" or
  # "England"). Without this the US-only list can't match such a value, so the
  # select renders blank and saving wipes the state — tripping the presence
  # validation on an otherwise-untouched address.
  def state_select_options(current = nil)
    return us_states if current.blank? || us_state?(current)

    us_states + [ [ current, current ] ]
  end

  # The countries gem's formal names that read poorly in a dropdown, keyed by ISO
  # code. Everything else keeps the gem's common name; the few that still differ
  # from the world-atlas names are aliased in world_map_chart_controller.js.
  PLAIN_COUNTRY_NAMES = {
    "RU" => "Russia", "SY" => "Syria", "LA" => "Laos", "BN" => "Brunei", "VA" => "Vatican City",
    "FM" => "Micronesia", "PS" => "Palestine", "CD" => "Democratic Republic of the Congo",
    "CG" => "Republic of the Congo", "VG" => "British Virgin Islands", "VI" => "U.S. Virgin Islands",
    "BQ" => "Caribbean Netherlands", "CC" => "Cocos Islands", "FK" => "Falkland Islands",
    "MF" => "Saint Martin", "SX" => "Sint Maarten", "SH" => "Saint Helena"
  }.freeze

  # Country dropdown options: the United States first, then every other country A–Z.
  # The US minor outlying islands are left out — nobody picks them for an address.
  # Picked from the state / territory dropdown, so never offered as a country.
  US_TERRITORY_CODES = %w[AS GU MP PR UM VI].freeze

  COUNTRIES = ([ Address::DEFAULT_COUNTRY ] + (
    ISO3166::Country.all.reject { |country| country.alpha2.in?(US_TERRITORY_CODES) }
      .map { |country| PLAIN_COUNTRY_NAMES[country.alpha2] || country.common_name } - [ Address::DEFAULT_COUNTRY ]
  ).sort).freeze
end
