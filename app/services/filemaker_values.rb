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
