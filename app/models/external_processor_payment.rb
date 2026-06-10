class ExternalProcessorPayment < Payment
  belongs_to :pay_charge, class_name: "Pay::Charge", optional: true
  attr_accessor :skip_pay_charge_validation

  validate :pay_charge_presence, unless: :skip_pay_charge_validation

  scope :with_metadata_key, ->(key, value) {
    where("JSON_EXTRACT(metadata, ?) = ?", "$.#{key}", value.as_json)
  }

  private

  def pay_charge_presence
    errors.add(:pay_charge_id, "must exist") if pay_charge_id.blank?
  end
end
