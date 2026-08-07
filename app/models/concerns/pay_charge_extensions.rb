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

    if (ce_registration_id = metadata["ce_registration_id"])
      create_ce_payment(ce_registration_id)
    elsif (event_registration_id = metadata["event_registration_id"])
      create_event_registration_payment(event_registration_id)
    elsif (form_submission_id = metadata["form_submission_id"])
      create_bulk_payment(form_submission_id)
    elsif (dues_subscription_id = dues_subscription_id_from_metadata)
      create_dues_payment(dues_subscription_id)
    elsif (person_id = metadata["person_id"])
      create_donation_payment(person_id)
    end
  end

  # Renewal charges carry no checkout metadata, so the link comes from the subscription
  # Pay already attached to this charge. Checkout charges are linked before Pay syncs the
  # subscription, so the id also comes from the invoice Pay stores on the charge.
  def dues_subscription_id_from_metadata
    metadata["dues_subscription_id"] ||
      subscription&.metadata&.dig("dues_subscription_id") ||
      data&.dig("stripe_invoice", "parent", "subscription_details", "metadata", "dues_subscription_id")
  end

  def create_dues_payment(dues_subscription_id)
    dues_subscription = DuesSubscription.find_by(id: dues_subscription_id)
    return unless dues_subscription

    person = dues_subscription.person
    return unless person

    term = Dues::EnsureTerm.call(dues_subscription: dues_subscription, covering: dues_period_date)
    return unless term

    payment = ExternalProcessorPayment.create!(
      stripe_charge_id: processor_id,
      external_origin: false,
      person: person,
      amount_cents: amount,
      amount_cents_remaining: amount,
      currency: currency,
      pay_charge_id: id,
      metadata: metadata.merge(stripe_charge: object)
    )

    allocation_amount = [ amount, term.remaining_cost ].min
    return unless allocation_amount > 0

    Allocation.create!(source: payment, allocatable: term, amount: allocation_amount)
  end

  # The invoice's billing period, so a renewal lands on the year it paid for rather than
  # the outgoing one a charge date can fall inside. Prefers the invoice period because it
  # is available before Pay links the subscription to the charge.
  def dues_period_date
    Time.use_zone(Dues::TIME_ZONE) do
      (invoice_period_start || subscription&.current_period_start || created_at || Time.current).to_date
    end
  end

  def invoice_period_start
    stamp = data&.dig("stripe_invoice", "period_start")
    Time.at(stamp) if stamp
  end

  def create_event_registration_payment(event_registration_id)
    registration = EventRegistration.find_by(id: event_registration_id)
    return unless registration

    person = registration.registrant
    return unless person

    payment = ExternalProcessorPayment.create!(
      stripe_charge_id: processor_id,
      external_origin: false,
      person: person,
      form_submission: FormSubmission.find_by(id: metadata["form_submission_id"]),
      amount_cents: amount,
      amount_cents_remaining: amount,
      currency: currency,
      pay_charge_id: id,
      metadata: metadata.merge(stripe_charge: object)
    )

    remaining_needed = registration.remaining_cost
    allocation_amount = [ amount, remaining_needed ].min

    if allocation_amount > 0
      Allocation.create!(
        source: payment,
        allocatable: registration,
        amount: allocation_amount
      )
    end

    registration.update!(payment_unresolved: false)
  end

  def create_ce_payment(ce_registration_id)
    ce_registration = ContinuingEducationRegistration.find_by(id: ce_registration_id)
    return unless ce_registration

    person = ce_registration.event_registration&.registrant
    return unless person

    payment = ExternalProcessorPayment.create!(
      stripe_charge_id: processor_id,
      external_origin: false,
      person: person,
      amount_cents: amount,
      amount_cents_remaining: amount,
      currency: currency,
      pay_charge_id: id,
      metadata: metadata.merge(stripe_charge: object)
    )

    remaining_needed = ce_registration.remaining_cost
    allocation_amount = [ amount, remaining_needed ].min

    if allocation_amount > 0
      Allocation.create!(
        source: payment,
        allocatable: ce_registration,
        amount: allocation_amount
      )
    end
  end

  def create_bulk_payment(form_submission_id)
    submission = FormSubmission.find_by(id: form_submission_id)
    return unless submission&.role == "bulk_payment"

    person = submission.person
    return unless person

    payment_metadata = metadata.dup
    attendee_answer = submission.form_answers
      .joins(:form_field)
      .where(form_fields: { field_identifier: "bulk_payment_attendees" })
      .first
    if attendee_answer&.submitted_answer.present?
      parsed = JSON.parse(attendee_answer.submitted_answer) rescue []
      payment_metadata[:attendees] = parsed
    end
    count_answer = submission.form_answers
      .joins(:form_field)
      .where(form_fields: { field_identifier: "number_of_attendees" })
      .first
    payment_metadata[:number_of_attendees] = count_answer&.submitted_answer&.to_i

    payment = ExternalProcessorPayment.create!(
      stripe_charge_id: processor_id,
      external_origin: false,
      person: person,
      form_submission: submission,
      amount_cents: amount,
      amount_cents_remaining: amount,
      currency: currency,
      pay_charge_id: id,
      metadata: payment_metadata.merge(stripe_charge: object)
    )
  end

  def create_donation_payment(person_id)
    person = Person.find_by(id: person_id.to_i)
    return unless person

    ExternalProcessorPayment.create!(
      stripe_charge_id: processor_id,
      external_origin: false,
      person: person,
      amount_cents: amount,
      amount_cents_remaining: amount,
      currency: currency,
      pay_charge_id: id,
      metadata: metadata.merge(stripe_charge: object)
    )
  end

  def sync_refunds
    refunds_data = object["refunds"]["data"] || []
    return if refunds_data.empty?

    external_payment = ExternalProcessorPayment.find_by(stripe_charge_id: processor_id)
    return unless external_payment

    refunds_data.each do |stripe_refund|
      next unless stripe_refund["status"] == "succeeded"
      next if Refund.exists?(stripe_refund_id: stripe_refund["id"])

      Refund.create!(
        refundable: external_payment,
        recipient: external_payment.person,
        amount_cents: stripe_refund["amount"],
        method: "stripe",
        stripe_refund_id: stripe_refund["id"]
      )
    end

    charge = Stripe::Charge.retrieve(
      { id: processor_id, expand: [ "refunds", "balance_transaction" ] },
      { stripe_account: stripe_account }.compact
    )

    external_payment.update!(metadata: (external_payment.metadata || {}).merge(stripe_charge: charge.to_hash))
  end
end
