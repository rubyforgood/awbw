class StripeChargeSucceededProcessor
  APP_METADATA_KEYS = %w[event_registration_id form_submission_id person_id].freeze

  def call(event)
    stripe_charge = event.data.object
    return unless stripe_charge.paid

    metadata = stripe_charge.metadata || {}

    return if (metadata.keys & APP_METADATA_KEYS).any?

    pay_charge = Pay::Charge.find_by(processor_id: stripe_charge.id)
    return if pay_charge && ExternalProcessorPayment.exists?(pay_charge_id: pay_charge.id)
    return if ExternalProcessorPayment.with_metadata_key("stripe_charge_id", stripe_charge.id).exists?

    person = resolve_person(stripe_charge, pay_charge)

    payment = ExternalProcessorPayment.new(
      person: person,
      pay_charge: pay_charge,
      amount_cents: stripe_charge.amount,
      amount_cents_remaining: stripe_charge.amount,
      currency: stripe_charge.currency,
      metadata: {
        stripe_charge_id: stripe_charge.id,
        stripe_charge: stripe_charge.to_hash
      }
    )
    payment.skip_pay_charge_validation = pay_charge.nil?
    payment.save!
  end

  private

  def resolve_person(stripe_charge, pay_charge)
    person_from_pay_charge(pay_charge) ||
      person_from_email(stripe_charge) ||
      external_payer
  end

  def person_from_pay_charge(pay_charge)
    owner = pay_charge&.customer&.owner
    owner if owner.is_a?(Person)
  end

  def person_from_email(stripe_charge)
    email = stripe_charge.billing_details&.email ||
            stripe_charge.receipt_email ||
            customer_email_from_stripe(stripe_charge.customer)
    Person.find_by(email: email) if email.present?
  end

  def customer_email_from_stripe(customer_id)
    return unless customer_id

    customer = Stripe::Customer.retrieve(customer_id)
    customer&.email
  rescue Stripe::StripeError
    nil
  end

  def external_payer
    Person.find_or_create_by!(first_name: "External", last_name: "Payer")
  end
end
