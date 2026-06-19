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

  Card = Data.define(:icon_class, :color, :title, :subtitle, :href, :target, :trailing_icon) do
    def display_icon_class = icon_class
    def theme = DomainTheme.swatch(color)
  end

  def initialize(event_registration)
    @registration = event_registration
    @event = event_registration.event
  end

  # The visible cards for this registration, in display order.
  def cards
    [ payment_card, certificate_card, scholarship_status_card, ce_hours_card,
      event_details_card, forms_card, handouts_card, portal_card,
      videoconference_card, faq_card ].compact
  end

  private

  attr_reader :registration, :event

  # Top card: an action card while a balance is due, a reference card once paid
  # in full. Its page lists every allocation with the running balance.
  def payment_card
    return if event.cost_cents.to_i <= 0
    due = registration.remaining_cost.to_i.positive?
    Card.new(icon_class: "fa-solid fa-credit-card", color: due ? "orange" : "green",
             title: "Payment",
             subtitle: due ? "#{MoneyFormatter.dollars_from_cents(registration.remaining_cost)} due — view your balance" : "Paid in full — view your payment history",
             href: registration_payment_path(registration.slug),
             target: nil, trailing_icon: due ? "fa-solid fa-arrow-right" : "fa-solid fa-circle-info")
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

  # Action card shown once the registrant has requested or received a
  # scholarship. Its page surfaces the award amount, funder, and tasks.
  def scholarship_status_card
    return unless registration.scholarship_requested? || registration.scholarship?
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
    return unless event.ce_hours_details.present? || registration.ce_credit_requested?
    complete = registration.ce_credit_requested? && registration.ce_hours_requested.present? && registration.ce_license_provided?
    Card.new(icon_class: "fa-solid fa-graduation-cap", color: complete ? "indigo" : "orange",
             title: event.ce_hours_details_label,
             subtitle: ce_hours_subtitle(complete),
             href: registration_ce_path(registration.slug),
             target: nil, trailing_icon: complete ? "fa-solid fa-circle-info" : "fa-solid fa-arrow-right")
  end

  def ce_hours_subtitle(complete)
    return "Continuing education — requirements & how to request" unless registration.ce_credit_requested?
    return "Add your CE hours and license number" unless complete
    "#{registration.ce_hours_requested} hours · #{MoneyFormatter.dollars_from_cents(registration.ce_amount_owed_cents)} due"
  end

  # "Art supplies & what to bring" — the event's own details page.
  def event_details_card
    return if event.event_details.blank?
    Card.new(icon_class: "fa-solid fa-circle-info", color: "amber",
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

  # Always-present reference card. Its page explains Facilitator Portal access and
  # links to the home screen.
  def portal_card
    Card.new(icon_class: "fa-solid fa-right-to-bracket", color: "rose",
             title: "Facilitator Portal access",
             subtitle: "Available once you complete both training days",
             href: registration_portal_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-circle-info")
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
    Card.new(icon_class: "fa-solid fa-circle-question", color: "purple",
             title: "Frequently asked questions",
             subtitle: "Common questions about the 2-day training",
             href: registration_faq_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-circle-info")
  end
end
