# Parses the dollar amounts admins type into forms into integer cents. Blank
# means "use the default"; anything else must be a non-negative number with at
# most two decimals, so a typo can't silently become $0. Companion to
# MoneyFormatter, which goes the other way (cents to display dollars).
class MoneyParser
  INVALID = :invalid_amount
  FORMAT = /\A\d+(\.\d{1,2})?\z/

  def self.cents(value)
    return if value.blank?

    normalized = value.to_s.strip
    return INVALID unless normalized.match?(FORMAT)

    (normalized.to_d * 100).to_i
  end

  def self.invalid?(cents) = cents == INVALID
end
