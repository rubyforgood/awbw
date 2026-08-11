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

  # Short-code payment indicators in the Payment column, rendered as colored text
  # (icon + code, like the "Intends to pay" note) rather than a chip. The first
  # three are keyed by the stored expected_payment_method string (FormBuilderService
  # payment options); BUD is the separate someone_else_will_pay boolean (buddy
  # system), shown in addition to the method — a registrant can have both. `classes`
  # is the text color.
  PaymentMethodBadge = Struct.new(:code, :label, :icon, :classes, keyword_init: true)

  PAYMENT_METHOD_BADGES = {
    FormBuilderService::PAYMENT_METHOD_PAY_NOW =>
      PaymentMethodBadge.new(code: "CCN", label: "Credit card", icon: "fa-solid fa-credit-card", classes: "text-green-600"),
    "Credit card (later)" =>
      PaymentMethodBadge.new(code: "CCL", label: "Credit card (later)", icon: "fa-regular fa-credit-card", classes: "text-amber-600"),
    "Check" =>
      PaymentMethodBadge.new(code: "CK", label: "Check", icon: "fa-solid fa-money-check-dollar", classes: "text-sky-600")
  }.freeze

  # Buddy system — someone else covers the cost (the someone_else_will_pay boolean).
  BUDDY_PAYMENT_BADGE = PaymentMethodBadge.new(
    code: "BUD", label: "Someone else will pay", icon: "fa-solid fa-user-group",
    classes: "text-purple-600"
  )

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

  # Payment badges shown beside the registrant's name: the expected-payment-method
  # code (if recorded) plus a BUD badge when someone else will pay. Either, both, or
  # neither. Unknown/custom method values fall back to a neutral badge so nothing is
  # silently hidden.
  def payment_badges
    badges = []
    if (value = expected_payment_method.presence)
      badges << (PAYMENT_METHOD_BADGES[value] || PaymentMethodBadge.new(
        code: value.truncate(8),
        label: value,
        icon: "fa-solid fa-money-bill",
        classes: "text-gray-600"
      ))
    end
    badges << BUDDY_PAYMENT_BADGE if someone_else_will_pay?
    badges
  end

  # Fixed option list ([label, value]) for the roster's Payment method filter, shown
  # on every paid event so the filter is always discoverable (mirroring the Payment
  # status filter). Values are the stored expected_payment_method strings, plus the
  # buddy-system sentinel.
  def self.payment_method_filter_choices
    PAYMENT_METHOD_BADGES.map { |value, badge| [ "#{badge.label} (#{badge.code})", value ] } +
      [ [ "#{BUDDY_PAYMENT_BADGE.label} (#{BUDDY_PAYMENT_BADGE.code})", EventRegistration::BUDDY_PAYMENT_FILTER ] ]
  end

  # Attendance-status pill styling — the single source of truth shared by the
  # editable badge on the registrants table and the read-only pill on the roster.
  ATTENDANCE_STATUS_CLASSES = {
    "registered" => "bg-blue-50 text-blue-700 border-blue-200",
    "attended" => "bg-green-50 text-green-700 border-green-200",
    "incomplete_attendance" => "bg-amber-50 text-amber-700 border-amber-200",
    "cancelled" => "bg-gray-50 text-gray-500 border-gray-200",
    "no_show" => "bg-red-50 text-red-700 border-red-200",
    "transferred_in" => "bg-teal-50 text-teal-700 border-teal-200",
    "transferred_out" => "bg-purple-50 text-purple-700 border-purple-200"
  }.freeze

  ATTENDANCE_STATUS_ICONS = {
    "registered" => "fa-clipboard-list",
    "attended" => "fa-circle-check",
    "incomplete_attendance" => "fa-clock",
    "cancelled" => "fa-ban",
    "no_show" => "fa-circle-xmark",
    "transferred_in" => "fa-right-to-bracket",
    "transferred_out" => "fa-right-from-bracket"
  }.freeze

  def attendance_status_classes
    ATTENDANCE_STATUS_CLASSES.fetch(status, "bg-gray-50 text-gray-500 border-gray-200")
  end

  def attendance_status_icon
    ATTENDANCE_STATUS_ICONS.fetch(status, "fa-question")
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

  # The LinkedIn "Add to Profile" deep link for this registration's facilitator
  # training credential. The credential name is the event title for now — revisit:
  # we may want a fixed credential name ("Art Workshop Facilitator") rather than the
  # per-training title. certUrl points at the public per-person verification page.
  def linkedin_add_to_profile_url
    LinkedinAddToProfileUrl.new(
      name: event.title,
      issued_on: event.end_date,
      cert_url: h.credential_url(slug),
      cert_id: slug,
      organization_name: ENV.fetch("ORGANIZATION_NAME", "A Window Between Worlds"),
      organization_id: ENV["LINKEDIN_ORGANIZATION_ID"].presence
    ).to_s
  end

  private

  def ce_badge(label, icon, color)
    CeBadge.new(label: label, icon: icon, classes: CE_BADGE_CLASSES.fetch(color))
  end
end
