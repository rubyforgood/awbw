class StripeChargeSucceededProcessor
  def call(event)
    stripe_charge = event.data.object
    return unless stripe_charge.paid

    return if Payment.exists?(stripe_charge_id: stripe_charge.id)

    pay_charge = Pay::Charge.find_by(processor_id: stripe_charge.id)

    person = resolve_person(stripe_charge, pay_charge)

    PaymentServices::RecordStripeCharge.call(
      charge: stripe_charge,
      person:,
      pay_charge:,
      metadata: { stripe_charge: stripe_charge.to_hash }
    )
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
