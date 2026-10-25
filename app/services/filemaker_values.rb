# How every FileMaker archive import reads a raw field value: dates in the archive's mixed
# formats, yes/no flags, contact types, and free text bounded to the column it lands in.
# Included by the importers so each reads the archive the same way.
module FilemakerValues
  module_function

  STRING_LIMIT = 255
  EMAIL_PATTERN = /[^\s,;<>"']+@[^\s,;<>"']+\.[^\s,;<>"']+/
  FALSE_FLAGS = %w[0 n no false].freeze
  DATE_FORMATS = %w[%m/%d/%Y %Y-%m-%d %m-%d-%Y %Y/%m/%d].freeze
  # A two-digit year below this is read as 20xx, at or above it as 19xx.
  TWO_DIGIT_YEAR_PIVOT = 10
  CONTACT_TYPES = AddressTranslation::CONTACT_TYPES
  # Organizations and projects staff retired in FileMaker by renaming them ("DELETE",
  # "… Do Not Use", "created in error"); the import leaves them out. P0038, P0798, P0825,
  # P2156 and P2524 are retired too but a portal org already carries each, so they import.
  RETIRED_RECORDS = %w[
    ORG00837 ORG02183 ORG02393 ORG02988 ORG03581 ORG03681 ORG04794 ORG06025 ORG06047
    ORG06175 ORG06183 ORG06184 ORG06186 ORG06188 ORG06189 ORG06190 ORG06197 ORG06208
    ORG06223 ORG06226 ORG06230 ORG06316 ORG06322 ORG06509 ORG06689 ORG06767 ORG06809
    ORG06981 P1405 P1630 P2228 P2255 P2262 P2312 P2344 P2370 P2394 P2416 P2465 P2466 P2475
    P2476 P2497 P2605 P2762
  ].freeze
  RETIRED_MARKER = /\b(do not use|delete)\b/i
  # Retired in FileMaker, but no namesake there shares a city with it, so it comes in as its
  # own organization, its name tidied of the marker and told apart by its code.
  RETIRED_RENAMED = %w[ORG01126 ORG02287 ORG05066].freeze
  # The retired organizations that duplicated another, by the code of the one they duplicated.
  # Each folds into it — code, blanks, addresses, phones, projects — so what names it lands there.
  RETIRED_DUPLICATE_OF = {
    "ORG00837" => "ORG06521",
    "ORG02183" => "ORG02184",
    "ORG02393" => "ORG02395",
    "ORG02988" => "ORG02990",
    "ORG03581" => "ORG03588",
    "ORG03681" => "ORG03682",
    "ORG04794" => "ORG04795",
    "ORG06025" => "ORG05702",
    "ORG06047" => "ORG05138",
    "ORG06175" => "ORG03150",
    "ORG06183" => "ORG01658",
    "ORG06184" => "ORG06049",
    "ORG06188" => "ORG05988",
    "ORG06189" => "ORG05580",
    "ORG06190" => "ORG04132",
    "ORG06197" => "ORG03185",
    "ORG06208" => "ORG01257",
    "ORG06223" => "ORG00636",
    "ORG06226" => "ORG02709",
    "ORG06230" => "ORG03243",
    "ORG06316" => "ORG01571",
    "ORG06322" => "ORG05340",
    "ORG06767" => "ORG06339",
    "ORG06981" => "ORG02607"
  }.freeze

  # Every string copied here lands in a varchar(255) the archive's free text isn't
  # bounded by, and an over-long incidental field would otherwise cost the record —
  # or, for a column with no length validation behind it, raise mid-import.
  def clip(value)
    value.presence && value.to_s.truncate(STRING_LIMIT)
  end

  # The archive words an email field freely ("Attn: someone", a note, two addresses at
  # once), so it's read for the addresses in it the portal's email validation accepts.
  def email_addresses(value)
    value.to_s.scan(EMAIL_PATTERN).select { |email| valid_email?(email) }
  end

  def valid_email?(email)
    email.length <= STRING_LIMIT && email.match?(URI::MailTo::EMAIL_REGEXP)
  end

  def retired_record?(code)
    RETIRED_RECORDS.include?(code.to_s.strip)
  end

  def duplicate_of(code)
    RETIRED_DUPLICATE_OF[code.to_s.strip]
  end

  def flag?(value)
    value.to_s.strip.presence && !FALSE_FLAGS.include?(value.to_s.strip.downcase)
  end

  # The archive's types map onto one set of ours, but each model declares the slice it
  # accepts — an address can be the mailing one, a phone number can't. A type we can't
  # place is left blank, which both models then record as unknown.
  def contact_type(value, allowed:)
    CONTACT_TYPES[value.to_s.strip.downcase].presence_in(allowed)
  end

  def parse_date(value)
    value = value.to_s.strip
    return if value.blank?

    DATE_FORMATS.each do |format|
      parsed = parse_with(value, format)
      return parsed if parsed
    end
    nil
  end

  # Parsing stops where the format ends, so "10-5-1983" read as %Y-%m-%d takes 19
  # as the day and drops the 83 — digits left over mean the format split the value
  # in the wrong place, so the next one gets its turn.
  def parse_with(value, format)
    parts = Date._strptime(value, format)
    return if parts.nil? || parts[:leftover].to_s.match?(/\A\d/)

    expand_century(Date.new(parts[:year], parts[:mon], parts[:mday]))
  rescue Date::Error, TypeError
    nil
  end

  # %Y reads a two-digit year as the year itself, so "10/5/83" is 83 AD. The archive
  # mixes two- and four-digit years, so a bare pair gets a century: 83 is 1983, 05 is 2005.
  def expand_century(date)
    return date if date.year >= 100

    date.change(year: date.year + (date.year < TWO_DIGIT_YEAR_PIVOT ? 2000 : 1900))
  end
end
