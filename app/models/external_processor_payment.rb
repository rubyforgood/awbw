class ExternalProcessorPayment < Payment
  belongs_to :pay_charge, class_name: "Pay::Charge", optional: true
  attr_accessor :skip_pay_charge_validation

  before_validation :clear_check_only_fields

  validate :pay_charge_presence, on: :create, unless: :skip_pay_charge_validation

  private

  def clear_check_only_fields
    self.check_number = nil
    self.memo = nil
  end

  def pay_charge_presence
    errors.add(:pay_charge_id, "must exist") if pay_charge_id.blank?
  end
end
