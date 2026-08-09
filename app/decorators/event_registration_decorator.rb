class EventRegistrationDecorator < ApplicationDecorator
  # The CE lifecycle badge, shared by every surface that shows CE status (the
  # registrants index, the CE callout, the CE card on the registration edit page).
  # One progression: Requested → License # needed → $X due → Pending → Issued.
  # Pending is blue, Issued is green, every actionable/in-progress state is amber.
  CeBadge = Struct.new(:label, :icon, :classes, keyword_init: true)

  CE_BADGE_CLASSES = {
    green: "bg-green-50 text-green-700 border-green-200",
    blue: "bg-blue-50 text-blue-700 border-blue-200",
    amber: "bg-amber-50 text-amber-700 border-amber-200"
  }.freeze

  # Short-code badge for the expected payment method, shown beside the registrant's
  # name on the roster so staff can read the payment type at a glance. Keyed by the
  # stored expected_payment_method string (FormBuilderService payment options).
  PaymentMethodBadge = Struct.new(:code, :label, :icon, :classes, keyword_init: true)

  PAYMENT_METHOD_BADGES = {
    FormBuilderService::PAYMENT_METHOD_PAY_NOW =>
      PaymentMethodBadge.new(code: "CCN", label: "Credit card (now)", icon: "fa-solid fa-credit-card", classes: "bg-green-50 text-green-700 border-green-200"),
    "Credit card (later)" =>
      PaymentMethodBadge.new(code: "CCL", label: "Credit card (later)", icon: "fa-regular fa-credit-card", classes: "bg-amber-50 text-amber-700 border-amber-200"),
    "Check" =>
      PaymentMethodBadge.new(code: "CK", label: "Check", icon: "fa-solid fa-money-check-dollar", classes: "bg-blue-50 text-blue-700 border-blue-200"),
    FormBuilderService::PAYMENT_METHOD_BUDDY =>
      PaymentMethodBadge.new(code: "BUD", label: "Buddy system", icon: "fa-solid fa-user-group", classes: "bg-purple-50 text-purple-700 border-purple-200")
  }.freeze

  # Nil when CE isn't in play (so the index can show a "Create" affordance instead).
  # `simulate_paid:` lets the CE callout's ?admin=true preview the post-payment state
  # without recording a payment.
  def ce_status_badge(simulate_paid: false)
    return unless ce_registered?
    return ce_badge("Issued", "fa-solid fa-circle-check", :green) if ce_certificate_issued?
    return ce_badge("License # needed", "fa-solid fa-id-card", :amber) unless ce_license_provided?
    return ce_badge("Pending", "fa-solid fa-hourglass-half", :blue) if ce_paid_in_full? || simulate_paid

    ce_badge("#{h.dollars_from_cents(ce_amount_due_cents)} due", "fa-solid fa-dollar-sign", :amber)
  end

  # Priority for sorting the CE column: most-complete first, "Create" (no CE) last.
  # Mirrors the ce_status_badge guard order so the two never drift.
  def ce_status_sort_key
    return 4 unless ce_registered?
    return 0 if ce_certificate_issued?
    return 3 unless ce_license_provided?
    return 1 if ce_paid_in_full?
    2
  end

  # Badge for the expected payment method, or nil when none is recorded. Unknown /
  # custom values fall back to a neutral badge showing the raw value so nothing is
  # silently hidden.
  def payment_method_badge
    value = expected_payment_method.presence
    return unless value

    PAYMENT_METHOD_BADGES[value] || PaymentMethodBadge.new(
      code: value.truncate(8),
      label: value,
      icon: "fa-solid fa-money-bill",
      classes: "bg-gray-50 text-gray-600 border-gray-200"
    )
  end

  # Roster "Payment method" filter options ([label, value]), built from the methods
  # actually present so codes that never appear (or custom values) aren't offered.
  # Ordered by PAYMENT_METHOD_BADGES, unknown values last.
  def self.payment_method_filter_options(values)
    values.compact_blank.uniq
      .sort_by { |value| PAYMENT_METHOD_BADGES.keys.index(value) || Float::INFINITY }
      .map { |value| [ payment_method_filter_label(value), value ] }
  end

  def self.payment_method_filter_label(value)
    badge = PAYMENT_METHOD_BADGES[value]
    badge ? "#{value} (#{badge.code})" : value
  end

  def title
    name
  end

  def detail(length: nil)
  end

  def link_target
    h.registration_ticket_path(slug)
  end

  # Human-readable explanation of why the Delete button is unavailable, or nil
  # when the registration is deletable. Reverted payments still leave allocation
  # rows, so they count here even though they net to zero — hence the aside.
  def deletion_blocked_reason
    return if deletable?

    reasons = []
    reasons << "financial records — payments, scholarships, discounts, or refunds (reverted payments still count)" if allocations.exists?
    reasons << "an attendance outcome on record (attended, incomplete, or no-show)" if attendance_recorded?
    reasons << "a transfer to another event" if transferred_out?
    "Can't be deleted — this registration has #{reasons.to_sentence}."
  end

  def default_display_image
    return event.primary_asset.file if event.respond_to?(:primary_asset) && event.primary_asset&.file&.attached?
    "theme_default.png"
  end

  private

  def ce_badge(label, icon, color)
    CeBadge.new(label: label, icon: icon, classes: CE_BADGE_CLASSES.fetch(color))
  end
end
