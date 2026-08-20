class ContinuingEducationRegistrationDecorator < ApplicationDecorator
  Badge = Struct.new(:label, :icon, :classes, keyword_init: true)

  PAYMENT_STATUS_BADGES = {
    "Paid" => Badge.new(label: "Paid", icon: "fa-solid fa-circle-check", classes: "bg-green-50 text-green-700 border-green-200"),
    "Partial" => Badge.new(label: "Partial", icon: "fa-solid fa-circle-half-stroke", classes: "bg-amber-50 text-amber-700 border-amber-200"),
    "Due" => Badge.new(label: "Due", icon: "fa-solid fa-dollar-sign", classes: "bg-red-50 text-red-700 border-red-200")
  }.freeze

  # Pill for the paid/partial/due state, keyed off the model's payment_status_label.
  def payment_status_badge
    PAYMENT_STATUS_BADGES.fetch(payment_status_label)
  end

  # Pill for whether the completion certificate has been issued.
  def certificate_badge
    if certificate_sent_at.present?
      Badge.new(label: "Issued", icon: "fa-solid fa-award", classes: "bg-green-50 text-green-700 border-green-200")
    else
      Badge.new(label: "Not issued", icon: "fa-regular fa-clock", classes: "bg-gray-50 text-gray-500 border-gray-200")
    end
  end

  # "LMFT #555" — kind and number as typed, or an em dash when neither is set.
  def license_label
    kind = professional_license&.kind.presence
    number = professional_license&.number.presence
    return "—" if kind.blank? && number.blank?
    [ kind, ("##{number}" if number) ].compact.join(" ")
  end
end
