# Comparison keys for address parts, so spellings of one place match: "123 North
# Main Street, Suite 4" and "123 N. Main St #4", "Saint Louis" and "St. Louis",
# "California" and "CA", "90001-1234" and "90001", "United States" and "USA".
# Only for matching — the stored address keeps whatever spelling it was saved with.
module AddressNormalizer
  module_function

  STREET_WORDS = {
    "street" => "st", "avenue" => "ave", "av" => "ave", "boulevard" => "blvd", "road" => "rd",
    "drive" => "dr", "lane" => "ln", "court" => "ct", "place" => "pl", "parkway" => "pkwy",
    "highway" => "hwy", "terrace" => "ter", "circle" => "cir", "square" => "sq", "trail" => "trl",
    "plaza" => "plz", "expressway" => "expy", "freeway" => "fwy", "center" => "ctr", "centre" => "ctr",
    "mount" => "mt", "fort" => "ft", "saint" => "st",
    "north" => "n", "south" => "s", "east" => "e", "west" => "w",
    "northeast" => "ne", "northwest" => "nw", "southeast" => "se", "southwest" => "sw",
    "first" => "1st", "second" => "2nd", "third" => "3rd", "fourth" => "4th", "fifth" => "5th",
    "sixth" => "6th", "seventh" => "7th", "eighth" => "8th", "ninth" => "9th", "tenth" => "10th",
    "building" => "bldg", "floor" => "fl", "room" => "rm"
  }.freeze

  # Every unit designator collapses to "#", so "Suite 4", "Ste. 4", "Apt 4" and "#4" match.
  UNIT_WORDS = %w[suite ste apartment apt unit #].freeze

  CITY_WORDS = { "saint" => "st", "sainte" => "ste", "mount" => "mt", "fort" => "ft" }.freeze

  STATE_NAMES = {
    "alabama" => "al", "alaska" => "ak", "arizona" => "az", "arkansas" => "ar", "california" => "ca",
    "colorado" => "co", "connecticut" => "ct", "delaware" => "de", "district of columbia" => "dc",
    "washington dc" => "dc", "florida" => "fl", "georgia" => "ga", "hawaii" => "hi", "idaho" => "id",
    "illinois" => "il", "indiana" => "in", "iowa" => "ia", "kansas" => "ks", "kentucky" => "ky",
    "louisiana" => "la", "maine" => "me", "maryland" => "md", "massachusetts" => "ma", "michigan" => "mi",
    "minnesota" => "mn", "mississippi" => "ms", "missouri" => "mo", "montana" => "mt", "nebraska" => "ne",
    "nevada" => "nv", "new hampshire" => "nh", "new jersey" => "nj", "new mexico" => "nm",
    "new york" => "ny", "north carolina" => "nc", "north dakota" => "nd", "ohio" => "oh",
    "oklahoma" => "ok", "oregon" => "or", "pennsylvania" => "pa", "rhode island" => "ri",
    "south carolina" => "sc", "south dakota" => "sd", "tennessee" => "tn", "texas" => "tx", "utah" => "ut",
    "vermont" => "vt", "virginia" => "va", "washington" => "wa", "west virginia" => "wv",
    "wisconsin" => "wi", "wyoming" => "wy", "puerto rico" => "pr", "guam" => "gu",
    "us virgin islands" => "vi", "virgin islands" => "vi", "american samoa" => "as",
    "northern mariana islands" => "mp", "calif" => "ca", "cal" => "ca"
  }.freeze

  US_COUNTRY = "us"
  # Compared with spaces removed, so spaced initials ("U. S. A.") match too.
  US_COUNTRY_NAMES = %w[us usa america unitedstates unitedstatesofamerica usofamerica].freeze
  US_STATES = Address::US_STATE_ABBREVIATIONS.map(&:downcase).to_set.freeze

  def street(value)
    tokens = words(value.to_s.gsub("#", " # ").gsub(/post\s+office\s+box/i, "po box"))
    tokens = tokens.each_with_index.map do |token, index|
      next "#" if UNIT_WORDS.include?(token) && index.positive?

      STREET_WORDS.fetch(token, token)
    end
    tokens.chunk_while { |a, b| a == "#" && b == "#" }.map(&:first).join(" ")
  end

  def city(value)
    words(value).map { |token| CITY_WORDS.fetch(token, token) }.join(" ")
  end

  def state(value)
    key = words(value).join(" ")
    STATE_NAMES.fetch(key, key)
  end

  # A US ZIP+4 compares on its first five digits; other postal codes ignore spacing.
  def zip(value)
    raw = value.to_s.strip
    return raw[0, 5] if raw.match?(/\A\d{5}(?:[\s-]?\d{4})?\z/)

    raw.downcase.delete("^a-z0-9")
  end

  # A blank country on an address in a US state is the US.
  def country(value, in_state: nil)
    key = words(value).join(" ").delete_prefix("the ")
    return US_COUNTRY if US_COUNTRY_NAMES.include?(key.delete(" "))
    return US_COUNTRY if key.blank? && US_STATES.include?(state(in_state))

    key
  end

  def county(value)
    tokens = words(value)
    tokens.pop if tokens.size > 1 && tokens.last == "county"
    tokens.join(" ")
  end

  # Blank for a type or locality recorded as "unknown", so it matches any known value.
  def known_text(value)
    key = text(value)
    key == "unknown" ? "" : key
  end

  def text(value)
    words(value).join(" ")
  end

  # The whole-address key AddressDeduper merges on: two addresses with one
  # signature are the same place recorded twice.
  def signature(address)
    [
      street(address.street_address),
      city(address.city),
      state(address.state),
      zip(address.zip_code),
      country(address.country, in_state: address.state),
      county(address.county),
      text(address.district),
      known_text(address.address_type),
      known_text(address.locality)
    ]
  end

  def words(value)
    value.to_s.downcase.tr(".,'", "").gsub(/[^a-z0-9#]+/, " ").split
  end
end
