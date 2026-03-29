class ExternalProcessorPayment < Payment
  belongs_to :pay_charge, class_name: "Pay::Charge"
  validates :pay_charge_id, presence: true
end
