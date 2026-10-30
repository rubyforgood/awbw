class ContinuingEducationRegistrationDecorator < ApplicationDecorator
  Badge = Struct.new(:label, :icon, :classes, keyword_init: true)
  Condition = Struct.new(:label, :met, keyword_init: true)

  PAYMENT_STATUS_BADGES = {
    "Paid" => Badge.new(label: "Paid", icon: "fa-solid fa-circle-check", classes: "bg-green-50 text-green-700 border-green-200"),
    "Partial" => Badge.new(label: "Partial", icon: "fa-solid fa-circle-half-stroke", classes: "bg-amber-50 text-amber-700 border-amber-200"),
    "Due" => Badge.new(label: "Due", icon: "fa-solid fa-dollar-sign", classes: "bg-red-50 text-red-700 border-red-200")
  }.freeze

  # Pill for the paid/partial/due state, keyed off the model's payment_status_label.
  def payment_status_badge
    PAYMENT_STATUS_BADGES.fetch(payment_status_label)
  end

  # Warning pill when the record is over-allocated — more allocated than it costs,
  # e.g. a $0 CE that still carries a payment — nil otherwise. Signals an admin needs
  # to reconcile the payments.
  def overpayment_badge
    return unless over_allocated?

    Badge.new(label: "Check payments", icon: "fa-solid fa-triangle-exclamation", classes: "bg-amber-50 text-amber-700 border-amber-200")
  end

  # Why the Delete button is hidden; nil when the record can be deleted.
  def deletion_blocked_reason
    return if deletable?

    "Can't be deleted — this CE registration has payment records (reverted payments still count), which stay linked to it."
  end

  # Pill for whether the completion certificate has been issued.
  def certificate_badge
    if certificate_sent_at.present?
      Badge.new(label: "Issued", icon: "fa-solid fa-award", classes: "bg-green-50 text-green-700 border-green-200")
    else
      Badge.new(label: "Not issued", icon: "fa-regular fa-clock", classes: "bg-gray-50 text-gray-500 border-gray-200")
    end
  end

  # The registrant-facing conditions behind #certificate_available?, each with whether it's met.
  def certificate_conditions
    event = event_registration.event
    ce_form = RegistrantCeForm.new(event_registration)
    ended_label = [ "the training has ended", ("(#{event.end_date.to_date.strftime("%B %-d, %Y")})" if event.end_date) ].compact.join(" ")
    conditions = [
      Condition.new(label: ended_label, met: event.end_date&.past?),
      Condition.new(label: "your attendance is confirmed", met: event_registration.attended?),
      Condition.new(label: "your CE payment is received in full", met: paid_in_full?)
    ]
    conditions << Condition.new(label: "#{ce_form.form.display_name} is complete", met: ce_form.complete?) if ce_form.form
    if event_registration.attendance_minutes_total.positive?
      conditions << Condition.new(label: "your signed-in time covers the CE hours", met: attendance_time_sufficient?)
    end
    conditions
  end

  def certificate_locked_reason
    unmet = certificate_conditions.reject(&:met).map(&:label)
    return if unmet.empty?

    "Unlocks once #{unmet.to_sentence}"
  end

  # "LMFT #555" — kind and number as typed, or an em dash when neither is set.
  def license_label
    kind = professional_license&.kind.presence
    number = professional_license&.number.presence
    return "—" if kind.blank? && number.blank?
    [ kind, ("##{number}" if number) ].compact.join(" ")
  end
end
