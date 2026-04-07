module PayChargeExtensions
  extend ActiveSupport::Concern

  included do
    after_save_commit :create_external_processor_payment
    after_save_commit :sync_refunds
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

  def sync_refunds
    refunds_data = object["refunds"]["data"] || []
    return if refunds_data.empty?

    external_payment = ExternalProcessorPayment.find_by(pay_charge_id: id)
    return unless external_payment

    refunds_data.each do |stripe_refund|
      next unless stripe_refund["status"] == "succeeded"
      next if Refund.exists?(stripe_refund_id: stripe_refund["id"])

      Refund.create!(
        refundable: external_payment,
        recipient: external_payment.payer,
        amount_cents: stripe_refund["amount"],
        method: "stripe",
        stripe_refund_id: stripe_refund["id"]
      )

      external_payment.update!(
        amount_cents_remaining: external_payment.amount_cents_remaining - stripe_refund["amount"]
      )
    end
  end
end
