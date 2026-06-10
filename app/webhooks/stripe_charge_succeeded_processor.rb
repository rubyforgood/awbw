class StripeChargeSucceededProcessor
  APP_METADATA_KEYS = %w[event_registration_id form_submission_id person_id].freeze

  def call(event)
    stripe_charge = event.data.object
    return unless stripe_charge.paid

    metadata = stripe_charge.metadata || {}
    return if (metadata.keys & APP_METADATA_KEYS).any?
    return if ExternalProcessorPayment.with_metadata_key("stripe_charge_id", stripe_charge.id).exists?

    pay_charge = Pay::Charge.find_by(processor_id: stripe_charge.id)
    return if pay_charge && ExternalProcessorPayment.exists?(pay_charge_id: pay_charge.id)
    create_payment(stripe_charge, pay_charge: pay_charge)
  end

  private

  def create_payment(stripe_charge, pay_charge: nil)
    payment = ExternalProcessorPayment.new(
      person: external_payer,
      amount_cents: stripe_charge.amount,
      amount_cents_remaining: stripe_charge.amount,
      currency: stripe_charge.currency,
      pay_charge_id: pay_charge&.id,
      metadata: {
        stripe_charge_id: stripe_charge.id,
        stripe_charge: stripe_charge.to_hash
      }
    )
    payment.skip_pay_charge_validation = true if pay_charge.nil?
    payment.save!
  end

  def external_payer
    Person.find_or_create_by!(first_name: "External", last_name: "Payer")
  end
end
