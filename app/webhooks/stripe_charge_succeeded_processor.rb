class StripeChargeSucceededProcessor
  APP_METADATA_KEYS = %w[event_registration_id form_submission_id person_id].freeze

  def call(event)
    stripe_charge = event.data.object
    return unless stripe_charge.paid

    metadata = stripe_charge.metadata || {}

    return if (metadata.keys & APP_METADATA_KEYS).any?
    return if Pay::Charge.exists?(processor_id: stripe_charge.id)
    return if ExternalProcessorPayment.with_metadata_key("stripe_charge_id", stripe_charge.id).exists?

    payment = ExternalProcessorPayment.new(
      person: anonymous_payer,
      amount_cents: stripe_charge.amount,
      amount_cents_remaining: stripe_charge.amount,
      currency: stripe_charge.currency,
      metadata: {
        stripe_charge_id: stripe_charge.id,
        stripe_charge: stripe_charge.to_hash
      }
    )
    payment.skip_pay_charge_validation = true
    payment.save!
  end

  private

  def anonymous_payer
    Person.find_or_create_by!(first_name: "External", last_name: "Payer")
  end
end
