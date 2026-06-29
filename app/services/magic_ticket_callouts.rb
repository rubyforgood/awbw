# "Magic" ticket callouts are code-defined cards on a registration ticket whose
# presence and content the app controls — unlike admin-configured
# RegistrationTicketCallouts, which admins create and reorder. Each magic card
# knows its own visibility rule (e.g. the payment card switches between an action
# and a reference card depending on whether a balance is due) and where it links.
#
# They render through the same _callout_card partial as admin callouts, so each
# card exposes that partial's presentation interface (#display_icon_class,
# #theme, #title, #subtitle) plus its own #href / #target / #trailing_icon.
class MagicTicketCallouts
  include Rails.application.routes.url_helpers

  # `badge` / `badge_classes` are an optional status chip shown inline in the
  # subtitle row (the payment card's "$1,350 due" / "Paid", the CE card's amount
  # owed, the scholarship award). `badge_classes` defaults to amber in the
  # _callout_card partial; both default to nil so chip-less cards are unchanged.
  Card = Data.define(:icon_class, :color, :title, :subtitle, :href, :target, :trailing_icon, :badge, :badge_classes) do
    def initialize(badge: nil, badge_classes: nil, **rest)
      super(badge:, badge_classes:, **rest)
    end

    def display_icon_class = icon_class
    def theme = DomainTheme.swatch(color)
  end

  # A registration-free description of one built-in card, for the event editor's
  # callouts section. `key` is :ce_hours / :event_details for the two whose text
  # admins edit; nil for the cards the app fully controls (shown greyed out).
  # `subtitle` mirrors the card's ticket subtitle; `visibility` describes when the
  # app shows it (rendered next to the "Built in" chip in the editor); `note` is an
  # optional extra hint on where the card's content comes from.
  EditorCard = Data.define(:key, :icon_class, :color, :title, :subtitle, :visibility, :note) do
    def theme = DomainTheme.swatch(color)
    def editable? = key.present?
  end

  # Every built-in card in the order it appears on a ticket, for the editor to
  # preview the full ticket context. Keep in sync with #cards: add a card method,
  # add it here.
  def self.editor_cards(event)
    [
      EditorCard.new(nil, "fa-solid fa-credit-card", "orange", "Payment", "Your balance and payment history", "When the event has a cost", nil),
      EditorCard.new(nil, "fa-solid fa-certificate", "green", "Certificate of completion", "View and download your certificate", "Once the certificate is unlocked", nil),
      EditorCard.new(nil, "fa-solid fa-award", "fuchsia", "Scholarship", "Your scholarship request and award", "When the registrant requested a scholarship", nil),
      EditorCard.new(:ce_hours, "fa-solid fa-graduation-cap", "teal", event.ce_hours_details_label, "Continuing education — requirements & how to request", "When a registrant requests CE credit", nil),
      EditorCard.new(:event_details, "fa-solid fa-palette", "blue", event.event_details_label, "Important info for this event — please read", "When the content below is filled in", nil),
      EditorCard.new(nil, "fa-solid fa-video", "blue", "Videoconference", "Join link and how to add it to your calendar", "When the event has a videoconference link", "Details come from this event's videoconference settings."),
      EditorCard.new(nil, "fa-solid fa-file-lines", "blue", "Forms", "W-9, invoice, and receipt", "On facilitator trainings and paid events", "Items link to their relevant resources."),
      EditorCard.new(nil, "fa-solid fa-folder-open", "blue", "Handouts", "Worksheets and resources for the training", "On facilitator trainings", "Items link to their relevant resources."),
      EditorCard.new(nil, "fa-solid fa-circle-question", "blue", "Frequently asked questions", "Common questions about the 2-day training", "On facilitator trainings", nil)
    ]
  end

  def initialize(event_registration)
    @registration = event_registration
    @event = event_registration.event
  end

  # The visible cards for this registration, in display order.
  def cards
    [ payment_card, certificate_card, scholarship_status_card, ce_hours_card,
      event_details_card, videoconference_card, forms_card, handouts_card,
      faq_card ].compact
  end

  private

  attr_reader :registration, :event

  # Top card: an action card while a balance is due, a reference card once paid
  # in full. Its page lists every allocation with the running balance.
  def payment_card
    return if event.cost_cents.to_i <= 0
    due = registration.remaining_cost.to_i.positive?
    Card.new(icon_class: "fa-solid fa-credit-card", color: due ? "orange" : "blue",
             title: due ? "Make your payment" : "Payment",
             subtitle: due ? "view your balance" : "view your payment history",
             badge: due ? "#{MoneyFormatter.dollars_from_cents(registration.remaining_cost)} due" : "Paid",
             badge_classes: due ? nil : "bg-blue-100 text-blue-800 border border-blue-300",
             href: registration_payment_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  # Shown only once the certificate of completion is unlocked (training over,
  # attended, scholarship tasks met). Renders like the invoice.
  def certificate_card
    return unless registration.certificate_available?
    Card.new(icon_class: "fa-solid fa-certificate", color: "green",
             title: "Certificate of completion",
             subtitle: "View and download your certificate",
             href: registration_certificate_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  # Shown only when the registrant requested a scholarship. Its page surfaces the
  # award amount, funder, and tasks once awarded. Awarded but with tasks still
  # pending shows an amber "$X · Tasks outstanding" badge (action needed); fully
  # met shows a fuchsia amount badge.
  def scholarship_status_card
    return unless registration.scholarship_requested?
    awarded = registration.scholarship?
    tasks_outstanding = awarded && !registration.scholarship_tasks_met?
    Card.new(icon_class: "fa-solid fa-award", color: DomainTheme.color_for(:scholarships).to_s,
             title: "Scholarship",
             subtitle: awarded ? "Your award — amount, funder, and tasks" : "Your scholarship request status",
             href: registration_scholarship_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right",
             badge: scholarship_badge(awarded, tasks_outstanding),
             badge_classes: tasks_outstanding ? nil : "bg-fuchsia-100 text-fuchsia-800 border border-fuchsia-300")
  end

  def scholarship_badge(awarded, tasks_outstanding)
    return unless awarded
    amount = MoneyFormatter.dollars_from_cents(registration.scholarships.sum(:amount_cents))
    tasks_outstanding ? "#{amount} · Tasks outstanding" : amount
  end

  # CE hours: an action card prompting the registrant to request credit until
  # they have, becoming a reference card once requested with hours and a license
  # number on file. Shown when the event offers CE or the registrant asked for it.
  def ce_hours_card
    return unless registration.ce_registered?
    complete = registration.ce_license_provided?
    Card.new(icon_class: "fa-solid fa-graduation-cap", color: "teal",
             title: event.ce_hours_details_label,
             subtitle: ce_hours_subtitle,
             href: registration_ce_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right",
             badge: ce_hours_badge(complete),
             # Amber while hours/license are still needed, teal once it's just the
             # amount due (nil badge_classes falls back to amber in _callout_card).
             badge_classes: complete ? "bg-teal-100 text-teal-800 border border-teal-300" : nil)
  end

  def ce_hours_subtitle
    hours = ContinuingEducationRegistration.format_hours(event.ce_hours_offered)
    hours.present? ? "#{hours} hours" : "Continuing education credit"
  end

  # Teal "$X due" once hours + license are on file and money is owed; otherwise an
  # amber chip naming what's still needed, prefixed with the amount when the hours
  # (and so the fee) are already known — e.g. "$250 · License number needed".
  def ce_hours_badge(complete)
    amount_cents = registration.ce_amount_owed_cents.to_i
    amount = MoneyFormatter.dollars_from_cents(amount_cents)

    if complete
      return unless amount_cents.positive?
      return "#{amount} due"
    end

    needed = ce_missing_text
    amount_cents.positive? ? "#{amount} · #{needed}" : needed
  end

  # Hours are set by the event now, so the only thing a requesting registrant can
  # still be missing is their license number.
  def ce_missing_text
    "License number needed"
  end

  # "Art supplies & what to bring" — the event's own details page.
  def event_details_card
    return if event.event_details.blank?
    Card.new(icon_class: "fa-solid fa-palette", color: "blue",
             title: event.event_details_label,
             subtitle: "Important info for this event — please read",
             href: details_event_path(event, reg: registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  # Shown only when the event has a videoconference URL set.
  def videoconference_card
    return if event.videoconference_url.blank?
    Card.new(icon_class: "fa-solid fa-video", color: "blue",
             title: "Videoconference",
             subtitle: registration.videoconference_details_visible? ? "Join link and add to your calendar" : "Unlocks once payment is on file",
             href: registration_videoconference_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  # Its page links to the W-9, the invoice, and the paid-in-full receipt (once
  # settled). Shown for facilitator trainings and any paid event (whose
  # registrants need their invoice/receipt) — see Event#show_forms_callout?.
  def forms_card
    return unless event.show_forms_callout?
    Card.new(icon_class: "fa-solid fa-file-lines", color: "blue",
             title: "Forms",
             subtitle: "W-9, invoice, and receipt",
             href: registration_forms_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  # Links to the 2-day training worksheets and handouts, so shown only on
  # facilitator trainings — see Event#show_handouts_callout?.
  def handouts_card
    return unless event.show_handouts_callout?
    Card.new(icon_class: "fa-solid fa-folder-open", color: "blue",
             title: "Handouts",
             subtitle: "Worksheets and resources for the training",
             href: registration_handouts_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  # Reference card linking to the 2-day training FAQ page, so shown only on
  # facilitator trainings — see Event#show_faq_callout?.
  def faq_card
    return unless event.show_faq_callout?
    Card.new(icon_class: "fa-solid fa-circle-question", color: "blue",
             title: "Frequently asked questions",
             subtitle: "Common questions about the 2-day training",
             href: registration_faq_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end
end
