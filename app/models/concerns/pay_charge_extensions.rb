module PayChargeExtensions
  extend ActiveSupport::Concern

  included do
    after_save_commit :create_external_processor_payment
  end

  private

  def create_external_processor_payment
    return if ExternalProcessorPayment.exists?(pay_charge_id: id)
    return unless object["paid"] == true

    person_id = metadata["person_id"]
    return unless person_id

    person = Person.find_by(id: person_id.to_i)
    return unless person

    ExternalProcessorPayment.create!(
      payer: person,
      amount_cents: amount,
      amount_cents_remaining: amount,
      currency: currency,
      pay_charge_id: id
    )
  end
end
