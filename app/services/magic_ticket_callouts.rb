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

  Card = Data.define(:icon_class, :color, :title, :subtitle, :href, :target, :trailing_icon, :chip) do
    def initialize(chip: nil, **) = super
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
      EditorCard.new(nil, "fa-solid fa-file-lines", "blue", "Forms", "W-9, invoice, and letter to supervisors", "Always shown", "Items link to their relevant resources."),
      EditorCard.new(nil, "fa-solid fa-folder-open", "blue", "Handouts", "Worksheets and resources for the training", "Always shown", "Items link to their relevant resources."),
      EditorCard.new(nil, "fa-solid fa-circle-question", "blue", "Frequently asked questions", "Common questions about the 2-day training", "Always shown", nil),
      EditorCard.new(nil, "fa-solid fa-right-to-bracket", "gray", "Facilitator Portal access", "Sign in once the training is complete", "Always shown", nil)
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
      faq_card, portal_card ].compact
  end

  private

  attr_reader :registration, :event

  # Top card: an action card while a balance is due, a reference card once paid
  # in full. Its page lists every allocation with the running balance.
  def payment_card
    return if event.cost_cents.to_i <= 0
    due = registration.remaining_cost.to_i.positive?
    Card.new(icon_class: "fa-solid fa-credit-card", color: due ? "orange" : "blue",
             title: "Payment",
             subtitle: due ? "#{MoneyFormatter.dollars_from_cents(registration.remaining_cost)} due — view your balance" : "Paid in full — view your payment history",
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
  # award amount, funder, and tasks once awarded.
  def scholarship_status_card
    return unless registration.scholarship_requested?
    awarded = registration.scholarship?
    Card.new(icon_class: "fa-solid fa-award", color: DomainTheme.color_for(:scholarships).to_s,
             title: "Scholarship",
             subtitle: awarded ? "Your award — amount, funder, and tasks" : "Your scholarship request status",
             href: registration_scholarship_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  # CE hours: an action card prompting the registrant to request credit until
  # they have, becoming a reference card once requested with hours and a license
  # number on file. Shown when the event offers CE or the registrant asked for it.
  def ce_hours_card
    return unless registration.ce_credit_requested?
    complete = registration.ce_credit_requested? && registration.ce_hours_requested.present? && registration.ce_license_provided?
    Card.new(icon_class: "fa-solid fa-graduation-cap", color: "teal",
             title: event.ce_hours_details_label,
             subtitle: ce_hours_subtitle(complete),
             href: registration_ce_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right",
             chip: ce_hours_chip(complete))
  end

  def ce_hours_subtitle(complete)
    return "Continuing education — requirements & how to request" unless registration.ce_credit_requested?
    return "Add your CE hours and license number" unless complete
    "#{registration.ce_hours_requested} hours"
  end

  # Amount owed, shown as an amber chip on the card — matching the ticket's
  # "payment is due" chip. Only once the request is complete and money is owed.
  def ce_hours_chip(complete)
    return unless complete
    amount = registration.ce_amount_owed_cents.to_i
    return unless amount.positive?
    "#{MoneyFormatter.dollars_from_cents(amount)} due"
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

  # Always-present. Its page links to the W-9 (when requested), invoice (when
  # requested), and the letter to supervisors.
  def forms_card
    Card.new(icon_class: "fa-solid fa-file-lines", color: "blue",
             title: "Forms",
             subtitle: "W-9, invoice, and letter to supervisors",
             href: registration_forms_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  # Always-present. Its page links to the training worksheets and handouts.
  def handouts_card
    Card.new(icon_class: "fa-solid fa-folder-open", color: "blue",
             title: "Handouts",
             subtitle: "Worksheets and resources for the training",
             href: registration_handouts_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  # Always-present, shown last. Greyed out until the registrant can reach the
  # portal (completed the training with a usable account), then turns active (green).
  def portal_card
    access = registration.portal_access?
    Card.new(icon_class: "fa-solid fa-right-to-bracket", color: access ? "green" : "gray",
             title: "Facilitator Portal access",
             subtitle: access ? "Sign in to the Facilitator Portal" : "Complete both training days and pay your training fee to be granted access",
             href: registration_portal_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  # Shown when the event has a videoconference link. Its page has the join link
  # and the add-to-calendar options.
  def videoconference_card
    return if event.videoconference_url.blank?
    Card.new(icon_class: "fa-solid fa-video", color: "blue",
             title: "Videoconference",
             subtitle: "Join link and how to add it to your calendar",
             href: registration_videoconference_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  # Always-present reference card linking to the training FAQ page.
  def faq_card
    Card.new(icon_class: "fa-solid fa-circle-question", color: "blue",
             title: "Frequently asked questions",
             subtitle: "Common questions about the 2-day training",
             href: registration_faq_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end
end
