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
  # admins edit via event columns; nil for the cards the app fully controls (shown
  # greyed out). `magic_key` ties the card to its ticket behavior — once an event
  # has materialized that key into an editable row, the preview is dropped here and
  # the row is edited in the callout list instead. `subtitle` mirrors the card's
  # ticket subtitle; `visibility` describes when the app shows it (rendered next to
  # the "Built in" chip); `note` is an optional hint on where content comes from.
  EditorCard = Data.define(:key, :magic_key, :icon_class, :color, :title, :subtitle, :visibility, :note) do
    def theme = DomainTheme.swatch(color)
    def editable? = key.present?
  end

  # Every built-in card in the order it appears on a ticket, for the editor to
  # preview the full ticket context. Cards whose content the event has already
  # materialized are omitted — they're edited as real rows in the callout list.
  # Keep in sync with #cards: add a card method, add it here.
  def self.editor_cards(event)
    materialized = event.registration_ticket_callouts.magic.pluck(:magic_key).to_set
    [
      EditorCard.new(nil, "payment", "fa-solid fa-credit-card", "orange", "Payment", "Your balance and payment history", "When the event has a cost", nil),
      EditorCard.new(nil, "certificate", "fa-solid fa-certificate", "green", "Certificate of completion", "View and download your certificate", "Once the certificate is unlocked", nil),
      EditorCard.new(nil, "scholarship", "fa-solid fa-award", "fuchsia", "Scholarship", "Your scholarship request and award", "When the registrant requested a scholarship", nil),
      EditorCard.new(nil, "videoconference", "fa-solid fa-video", "blue", "Videoconference", "Join link and how to add it to your calendar", "When the event has a videoconference link", "Details come from this event's videoconference settings."),
      EditorCard.new(nil, "handouts", "fa-solid fa-folder-open", "blue", "Handouts", "Worksheets and resources for the training", "On facilitator trainings", "Items link to their relevant resources."),
      EditorCard.new(nil, "faq", "fa-solid fa-circle-question", "blue", "Frequently asked questions", "Common questions about the 2-day training", "On facilitator trainings", nil)
    ].reject { |card| card.key.nil? && materialized.include?(card.magic_key) }
  end

  # magic_key → builder method, in the default order cards appear on a ticket.
  CARD_BUILDERS = {
    "payment" => :payment_card,
    "certificate" => :certificate_card,
    "scholarship" => :scholarship_status_card,
    "ce_hours" => :ce_hours_card,
    "event_details" => :event_details_card,
    "videoconference" => :videoconference_card,
    "handouts" => :handouts_card,
    "faq" => :faq_card
  }.freeze

  def initialize(event_registration)
    @registration = event_registration
    @event = event_registration.event
  end

  # The visible built-in cards for this registration, in default order. Cards the
  # event has materialized into editable rows are omitted here — the ticket renders
  # those from the row (calling #card_for for behavioral ones), so this is both the
  # non-materialized set and the fallback for events not yet seeded.
  def cards
    CARD_BUILDERS.reject { |magic_key, _| materialized?(magic_key) || skip_in_fallback?(magic_key) }
                 .filter_map { |_, builder| send(builder) }
  end

  # The live Card for a materialized behavioral callout row, or nil when it
  # shouldn't show for this registration (e.g. certificate not yet unlocked). The
  # app supplies the dynamic parts (badge, per-registration visibility, and the
  # destination link); the row supplies the editable presentation (title,
  # subtitle, colour, icon), so admin edits to those take effect on the ticket.
  def card_for(callout)
    builder = CARD_BUILDERS[callout.magic_key]
    base = builder && send(builder)
    return unless base
    # Event details links to its page only when it has content to show.
    return if callout.magic_key == "event_details" && callout.description.blank?

    base.with(
      title: callout.title,
      subtitle: callout.subtitle,
      icon_class: callout.display_icon_class,
      # Payment (and any app-coloured card) keeps its live status colour, which
      # overrides the selected one; everything else honours the row's colour.
      color: callout.app_colored? ? base.color : (callout.color_class.presence || base.color)
    )
  end

  private

  attr_reader :registration, :event

  # A built-in card the event has materialized into an editable row renders from
  # that row, not from #cards, so we skip it here to avoid double-rendering.
  def materialized?(magic_key)
    @materialized_keys ||= event.registration_ticket_callouts.magic.pluck(:magic_key).to_set
    @materialized_keys.include?(magic_key)
  end

  # In the unseeded fallback, event-details content lives on the event column, so
  # hide the card when it's blank (the row path checks the row in #card_for).
  def skip_in_fallback?(magic_key)
    magic_key == "event_details" && event.event_details.blank?
  end

  # Top card: an action card while a balance is due, a reference card once paid
  # in full. Its page lists every allocation with the running balance, plus the
  # linked documents (the W-9, and the invoice/receipt) for paid events.
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
    # Awarded is display-only: the scholarship record exists earlier, but the award
    # is only shown as awarded once the recipient signs the agreement. Until then
    # the card prompts them to accept.
    awarded = registration.scholarship_awarded?
    needs_agreement = registration.scholarship? && !awarded
    tasks_outstanding = awarded && !registration.scholarship_tasks_met?
    action_needed = needs_agreement || tasks_outstanding
    Card.new(icon_class: "fa-solid fa-award",
             # Amber while an action is needed (accept the agreement, or complete
             # tasks), otherwise the scholarship colour.
             color: action_needed ? "amber" : DomainTheme.color_for(:scholarships).to_s,
             title: "Scholarship",
             subtitle: scholarship_subtitle(awarded, needs_agreement),
             href: registration_scholarship_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right",
             badge: scholarship_badge(awarded, tasks_outstanding),
             badge_classes: tasks_outstanding ? nil : "bg-fuchsia-100 text-fuchsia-800 border border-fuchsia-300")
  end

  def scholarship_subtitle(awarded, needs_agreement)
    return "Your award — amount, funder, and tasks" if awarded
    return "Review and accept your scholarship agreement" if needs_agreement
    "Your scholarship request status"
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
    hours = registration.continuing_education_registrations.first&.hours.to_d
    return "Continuing education credit" unless hours.positive?

    "#{NumberFormatter.plain(hours)} hours"
  end

  # Teal "$X due" once hours + license are on file and money is owed; otherwise an
  # amber chip naming what's still needed, prefixed with the amount when the hours
  # (and so the fee) are already known — e.g. "$250 · License number needed".
  def ce_hours_badge(complete)
    amount_cents = registration.continuing_education_registrations.first&.cost_cents.to_i
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
