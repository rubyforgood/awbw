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
    attendees = []
    if attendee_answer&.submitted_answer.present?
      attendees = JSON.parse(attendee_answer.submitted_answer) rescue []
      payment_metadata[:attendees] = attendees
    end
    count_answer = submission.form_answers
      .joins(:form_field)
      .where(form_fields: { field_identifier: "number_of_attendees" })
      .first
    payment_metadata[:number_of_attendees] = count_answer&.submitted_answer&.to_i

    payment = ExternalProcessorPayment.create!(
      person: person,
      form_submission: submission,
      amount_cents: amount,
      amount_cents_remaining: amount,
      currency: currency,
      pay_charge_id: id,
      metadata: payment_metadata
    )

    allocate_bulk_payment(payment, attendees, metadata["event_id"])
  end

  # Match each attendee to an existing registration by name + email and
  # allocate the amount the payer entered for them, capped at the registration's
  # remaining cost and the payment's unallocated balance. Ambiguous or unmatched
  # attendees are left for manual allocation.
  def allocate_bulk_payment(payment, attendees, event_id)
    return if event_id.blank?

    attendees.each do |attendee|
      registration = matching_registration(attendee, event_id)
      next unless registration

      allocation_amount = [
        bulk_attendee_amount_cents(attendee),
        registration.remaining_cost,
        payment.amount_cents_remaining
      ].min
      next unless allocation_amount > 0

      Allocation.create!(
        source: payment,
        allocatable: registration,
        amount: allocation_amount
      )
    end
  end

  def matching_registration(attendee, event_id)
    first_name = attendee["first_name"].to_s.strip
    last_name = attendee["last_name"].to_s.strip
    email = attendee["email"].to_s.strip
    return if first_name.blank? || last_name.blank? || email.blank?

    people = Person.where(
      "LOWER(first_name) = ? AND LOWER(last_name) = ? AND LOWER(email) = ?",
      first_name.downcase, last_name.downcase, email.downcase
    )
    return unless people.count == 1

    EventRegistration.find_by(event_id: event_id, registrant_id: people.first.id)
  end

  def bulk_attendee_amount_cents(attendee)
    amount = attendee["amount"].to_s.strip
    return 0 if amount.blank?

    (BigDecimal(amount) * 100).round
  rescue ArgumentError
    0
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
