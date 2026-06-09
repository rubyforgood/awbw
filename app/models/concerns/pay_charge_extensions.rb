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

    if (event_registration_id = metadata["event_registration_id"])
      create_event_registration_payment(event_registration_id)
    elsif (form_submission_id = metadata["form_submission_id"])
      create_bulk_payment(form_submission_id)
    elsif (person_id = metadata["person_id"])
      create_donation_payment(person_id)
    end
  end

  def create_event_registration_payment(event_registration_id)
    registration = EventRegistration.find_by(id: event_registration_id)
    return unless registration

    person = registration.registrant
    return unless person

    payment = ExternalProcessorPayment.create!(
      person: person,
      form_submission: FormSubmission.find_by(id: metadata["form_submission_id"]),
      amount_cents: amount,
      amount_cents_remaining: amount,
      currency: currency,
      pay_charge_id: id,
      metadata: metadata
    )

    remaining_needed = registration.remaining_cost
    allocation_amount = [ amount, remaining_needed ].min
    return unless allocation_amount > 0

    Allocation.create!(
      source: payment,
      allocatable: registration,
      amount: allocation_amount
    )
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
      payment_metadata[:attendee_count] = parsed.length
    end

    payment = ExternalProcessorPayment.create!(
      person: person,
      form_submission: submission,
      amount_cents: amount,
      amount_cents_remaining: amount,
      currency: currency,
      pay_charge_id: id,
      metadata: payment_metadata
    )
  end

  def create_donation_payment(person_id)
    person = Person.find_by(id: person_id.to_i)
    return unless person

    ExternalProcessorPayment.create!(
      person: person,
      amount_cents: amount,
      amount_cents_remaining: amount,
      currency: currency,
      pay_charge_id: id,
      metadata: metadata
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
        recipient: external_payment.person,
        amount_cents: stripe_refund["amount"],
        method: "stripe",
        stripe_refund_id: stripe_refund["id"]
      )
    end
  end
end
