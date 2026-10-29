# Parses the dollar amounts admins type into forms into integer cents. Blank
# means "use the default"; anything else must be a non-negative number with at
# most two decimals, so a typo can't silently become $0.
module DollarAmountParsing
  INVALID_AMOUNT = :invalid_amount
  AMOUNT_FORMAT = /\A\d+(\.\d{1,2})?\z/

  private

  def parse_cents(value)
    return if value.blank?

    normalized = value.to_s.strip
    return INVALID_AMOUNT unless normalized.match?(AMOUNT_FORMAT)

    (normalized.to_d * 100).to_i
  end
end
