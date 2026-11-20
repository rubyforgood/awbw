class ExternalProcessorPayment < Payment
  belongs_to :pay_charge, class_name: "Pay::Charge", optional: true
  attr_accessor :skip_pay_charge_validation

  scope :membership_originated, -> {
    where(
      "pay_charge_id IN (?) OR " \
      "JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.membership_invoice_id')) NOT IN ('', 'null') OR " \
      "JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.stripe_charge.metadata.membership_invoice_id')) " \
      "NOT IN ('', 'null')",
      MembershipChargeAttempt.where.not(pay_charge_id: nil).select(:pay_charge_id)
    )
  }

  before_validation :clear_check_only_fields

  validate :pay_charge_presence, on: :create, unless: :skip_pay_charge_validation

  def stripe_billing_details
    metadata&.dig("stripe_charge", "billing_details") || {}
  end

  def stripe_billing_name
    stripe_billing_details["name"].presence
  end

  def stripe_billing_email
    stripe_billing_details["email"].presence
  end

  def stripe_billing_phone
    stripe_billing_details["phone"].presence
  end

  def stripe_billing_address
    address = stripe_billing_details["address"] || {}

    [
      address["line1"],
      address["line2"],
      [ address["city"], address["state"], address["postal_code"] ].compact_blank.join(", ").presence,
      address["country"]
    ].compact_blank.join(", ").presence
  end

  def stripe_payment_method_type
    metadata&.dig("stripe_charge", "payment_method_details", "type") ||
      pay_charge&.data&.dig("payment_method_type")
  end

  def billing_name_differs_from_payer?
    return false if stripe_billing_name.blank?

    payer_name = payer.is_a?(Person) ? payer.full_name : payer&.name
    return false if payer_name.blank?

    name_key(stripe_billing_name) != name_key(payer_name)
  end

  private

  def name_key(name)
    words = Person.normalize_name(name).to_s
      .downcase
      .gsub(/['’]/, "")
      .gsub(/[[:punct:]]/, " ")
      .split

    words = words.reject { |word| word.length == 1 } if words.count { |word| word.length > 1 } >= 2

    [ words.first, words.last ].compact.sort
  end

  def clear_check_only_fields
    self.check_number = nil
    self.memo = nil
  end

  def pay_charge_presence
    errors.add(:pay_charge_id, "must exist") if pay_charge_id.blank?
  end
end
