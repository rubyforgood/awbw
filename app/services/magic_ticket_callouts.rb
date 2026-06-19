# "Magic" ticket callouts are code-defined cards on a registration ticket whose
# presence and content the app controls — unlike admin-configured
# RegistrationTicketCallouts, which admins create and reorder. Each magic card
# knows its own visibility rule (e.g. the invoice card only appears when the
# registrant requested an invoice during sign-up) and where it links.
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
    [ event_details_card, ce_hours_card, scholarship_status_card, w9_card, invoice_card,
      questions_next_steps_card ].compact
  end

  private

  attr_reader :registration, :event

  def event_details_card
    return if event.event_details.blank?
    Card.new(icon_class: "fa-solid fa-circle-info", color: "amber",
             title: event.event_details_label,
             subtitle: "Important info for this event — please read",
             href: details_event_path(event, reg: registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  def ce_hours_card
    return if event.ce_hours_details.blank?
    Card.new(icon_class: "fa-solid fa-graduation-cap", color: "indigo",
             title: event.ce_hours_details_label,
             subtitle: "Continuing education hours — requirements & next steps",
             href: ce_hours_event_path(event, reg: registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  # An action card (not reference) shown once the registrant has requested or
  # received a scholarship. Its show page surfaces the award amount, funder, and
  # tasks. Themed in the scholarships colour to match the rest of that UI.
  def scholarship_status_card
    return unless registration.scholarship_requested? || registration.scholarship?
    awarded = registration.scholarship?
    Card.new(icon_class: "fa-solid fa-award", color: DomainTheme.color_for(:scholarships).to_s,
             title: "Scholarship",
             subtitle: awarded ? "Your award — amount, funder, and tasks" : "Your scholarship request status",
             href: registration_scholarship_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  def w9_card
    return unless registration.w9_requested?
    Card.new(icon_class: "fa-solid fa-file-pdf", color: "blue",
             title: "Download W-9",
             subtitle: "AWBW's W-9 tax form for your records",
             href: "/documents/awbw-w9.pdf",
             target: "_blank", trailing_icon: "fa-solid fa-download")
  end

  # Always-present informational card, shown last. Its page has closing details
  # and a contact link for any questions.
  def questions_next_steps_card
    Card.new(icon_class: "fa-solid fa-envelope", color: "gray",
             title: "Questions & next steps",
             subtitle: "More details are on the way",
             href: registration_questions_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-circle-info")
  end

  def invoice_card
    return unless registration.invoice_requested?
    Card.new(icon_class: "fa-solid fa-file-invoice-dollar", color: "indigo",
             title: "View invoice",
             subtitle: "Itemized invoice for this registration",
             href: registration_invoice_path(registration.slug),
             target: "_blank", trailing_icon: "fa-solid fa-arrow-right")
  end
end
