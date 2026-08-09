# Renders the live, per-registration cards for a registrant's ticket. Given an
# EventRegistration, it turns each built-in callout into a display Card whose
# dynamic parts depend on that registration — the Payment card's balance and
# colour, the Certificate card only once it's unlocked, the Scholarship badge, and
# so on. Each card exposes the _callout_card partial's interface
# (#display_icon_class, #theme, #title, #subtitle) plus #href / #target /
# #trailing_icon.
#
# `#card_for(row)` overlays this live status onto a materialized built-in row: the
# row supplies the admin-edited title/subtitle/colour, this service supplies the
# badge, status colour, visibility guard, and destination. `#cards` is the code
# fallback for events whose built-ins aren't materialized yet. `.editor_cards`
# builds the greyed preview cards shown in the event editor.
#
# The callouts' definitions and materialization live in BuiltinCallouts; this
# service is only about how they render on a ticket.
class BuiltinCalloutCards
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
  # callouts section — a greyed-out preview of a card the app controls, so the full
  # ticket context is visible. `builtin_key` ties the card to its ticket behavior —
  # once an event has materialized that key into an editable row, the preview is
  # dropped here and the row is edited in the callout list instead. `subtitle`
  # mirrors the card's ticket subtitle; `visibility` describes when the app shows it
  # (rendered next to the "Built in" chip); `note` is an optional hint on where
  # content comes from.
  EditorCard = Data.define(:builtin_key, :icon_class, :color, :title, :subtitle, :visibility, :note) do
    def theme = DomainTheme.swatch(color)
  end

  # Every built-in card in the order it appears on a ticket, for the editor to
  # preview the full ticket context. Cards whose content the event has already
  # materialized are omitted — they're edited as real rows in the callout list.
  # Keep in sync with #cards: add a card method, add it here.
  def self.editor_cards(event)
    # Read the loaded/in-memory rows (not a DB pluck) so a new event's just-built,
    # not-yet-saved built-in rows count as materialized and aren't also previewed.
    materialized = event.registration_ticket_callouts.reject(&:marked_for_destruction?).filter_map(&:builtin_key).to_set
    [
      EditorCard.new("payment", "fa-solid fa-credit-card", "orange", "Payment", "Your balance and payment history", "When the event has a cost", nil),
      EditorCard.new("scholarship", "fa-solid fa-award", "fuchsia", "Scholarship", "Your scholarship request and award", "When the registrant requested a scholarship", nil),
      EditorCard.new("videoconference", "fa-solid fa-video", "blue", "Videoconference", "Join details and add to calendar links", "When the event has a videoconference link", "Details come from this event's videoconference settings."),
      EditorCard.new("staff", "fa-solid fa-people-group", "blue", "Meet the staff", "The team for this event", "When the event has staff", "The roster comes from this event's staff."),
      EditorCard.new("handouts", "fa-solid fa-folder-open", "blue", "Handouts", "Worksheets and resources for the event", "On facilitator trainings", "Items link to their relevant resources."),
      EditorCard.new("certificate", "fa-solid fa-certificate", "green", "Certificate of completion", "View and download your certificate", "Once the certificate is unlocked", nil),
      EditorCard.new("faq", "fa-solid fa-circle-question", "blue", "Frequently asked questions", "Common questions about the 2-day training", "On facilitator trainings", nil)
    ].reject { |card| materialized.include?(card.builtin_key) }
  end

  # builtin_key → builder method, in the default order cards appear on a ticket.
  # Content callouts (handouts, FAQ) only ever render from their materialized row
  # (the ticket's content branch), never from code, so they have no builder here.
  CARD_BUILDERS = {
    "payment" => :payment_card,
    "scholarship" => :scholarship_status_card,
    "ce_hours" => :ce_hours_card,
    "videoconference" => :videoconference_card,
    "staff" => :staff_card,
    "certificate" => :certificate_card
  }.freeze

  # Why a built-in card with this builtin_key can never appear on the given event's
  # ticket because the event lacks the config the card depends on (a free event
  # has no payment card, an event with no scholarship form has no scholarship
  # card, an event that offers no CE hours has no CE card) — or nil when the event
  # is configured for it. The card builders below enforce these same gaps at
  # render time; the editor surfaces the phrase as an amber "won't show" badge so
  # admins know a published callout still won't reach the ticket.
  def self.config_gap(event, builtin_key)
    case builtin_key
    when "payment"
      "this event is free" if event.cost_cents.to_i <= 0
    when "scholarship"
      "this event has no scholarship form" if event.scholarship_form.blank?
    when "ce_hours"
      "this event offers no CE hours" unless event.ce_eligible?
    when "videoconference"
      "this event has no videoconference link" if event.videoconference_url.blank?
    when "staff"
      "this event has no staff" unless event.event_staffs.exists?
    end
  end

  # Action-oriented companion to #config_gap for the editor: what the admin must
  # configure for this built-in to reach the ticket, or nil when the event is
  # already set up for it (or the built-in has no config dependency). Mirrors
  # #config_gap's conditions so the two can't drift.
  def self.config_gap_action(event, builtin_key)
    return unless config_gap(event, builtin_key)
    {
      "payment" => "set an event cost above $0",
      "scholarship" => "add a scholarship form under form settings",
      "ce_hours" => "set CE hours above 0 under form settings",
      "videoconference" => "add a videoconference link",
      "staff" => "connect some staff"
    }[builtin_key]
  end

  # `preview: true` is the sample ticket: it bypasses the config gaps so an admin
  # can preview (and click through) a published built-in card even before the
  # event carries the config it depends on (a cost, a scholarship form, CE hours).
  def initialize(event_registration, preview: false)
    @registration = event_registration
    @event = event_registration.event
    @preview = preview
  end

  # The visible built-in cards for this registration, in default order. Cards the
  # event has materialized into editable rows are omitted here — the ticket renders
  # those from the row (calling #card_for for behavioral ones), so this is both the
  # non-materialized set and the fallback for events not yet seeded.
  def cards
    CARD_BUILDERS.reject { |builtin_key, _| materialized?(builtin_key) }
                 .filter_map { |_, builder| send(builder) }
  end

  # The live Card for a materialized behavioral callout row, or nil when it
  # shouldn't show for this registration (e.g. no videoconference link set). The
  # app supplies the dynamic parts (badge, per-registration visibility, and the
  # destination link); the row supplies the editable presentation (title,
  # subtitle, colour, icon), so admin edits to those take effect on the ticket.
  def card_for(callout)
    builder = CARD_BUILDERS[callout.builtin_key]
    base = builder && send(builder)
    # A published certificate row shows even before it unlocks (as a pending card);
    # the fallback set only surfaces it once downloadable, so this lives here.
    base ||= certificate_pending_card if callout.builtin_key == "certificate"
    return unless base

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

  # Whether this event lacks the config the built-in card depends on, so it can't
  # reach a real ticket. The sample-ticket preview ignores the gap so an admin can
  # still see and click through the card while finishing the event's setup.
  def config_gap?(builtin_key)
    !@preview && self.class.config_gap(event, builtin_key).present?
  end

  # A built-in card the event has materialized into an editable row renders from
  # that row, not from #cards, so we skip it here to avoid double-rendering.
  # Reads the (possibly preloaded) association in Ruby rather than a `.pluck`,
  # so a preloaded ticket render doesn't issue a second query for the same rows.
  def materialized?(builtin_key)
    @materialized_keys ||= event.registration_ticket_callouts.filter_map(&:builtin_key).to_set
    @materialized_keys.include?(builtin_key)
  end

  # Top card: an action card while a balance is due, a reference card once paid
  # in full. Its page lists every allocation with the running balance, plus the
  # linked documents (the W-9, and the invoice/receipt) for paid events.
  # Unlike scholarship/CE/videoconference, payment never bypasses its gap in
  # preview — a free event truly has no balance to preview, on a real ticket or
  # a sample one, so there's nothing to click through.
  def payment_card
    return if self.class.config_gap(event, "payment")
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
  # attended, scholarship tasks met). Renders like the invoice. A published
  # certificate row also shows before then via #certificate_pending_card.
  def certificate_card
    return unless registration.certificate_available?
    Card.new(icon_class: "fa-solid fa-certificate", color: "green",
             title: "Certificate of completion",
             subtitle: "View and download your certificate",
             href: registration_certificate_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  # A published certificate row still shows before it unlocks, badged as pending so
  # the registrant knows one is coming; its page lists the outstanding conditions.
  # Badge is the one presentation the row can't override, so the cue survives
  # #card_for. Only reached via a published row — the code-defined fallback set
  # (#cards) surfaces the certificate only once it's actually downloadable.
  def certificate_pending_card
    Card.new(icon_class: "fa-solid fa-certificate", color: "gray",
             title: "Certificate of completion",
             subtitle: "Unlocks after the training",
             href: registration_certificate_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right",
             badge: "Available after the event",
             badge_classes: "bg-gray-100 text-gray-600 border border-gray-300")
  end

  # Shown only when the registrant requested a scholarship. Its page surfaces the
  # award amount, funder, and tasks once awarded. Awarded but with tasks still
  # pending shows an amber "$X · Tasks outstanding" badge (action needed); fully
  # met shows a fuchsia amount badge.
  def scholarship_status_card
    return if config_gap?("scholarship")
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
  # Before they've requested, it's the invite card — but only while the request
  # window is still open (see #ce_request_open?).
  def ce_hours_card
    return if config_gap?("ce_hours")
    unless registration.ce_registered?
      # The sample-ticket preview models CE only through its "Show all options"
      # toggle (which builds a CE registration), so don't surface the invite there.
      return unless !@preview && ce_request_open?
      return ce_request_card
    end
    complete = registration.ce_license_provided?
    # An outstanding CE balance turns the card orange (an action card), matching
    # the payment card, rather than the resting teal.
    due = registration.continuing_education_registrations.first&.remaining_cost.to_i.positive?
    Card.new(icon_class: "fa-solid fa-graduation-cap", color: due ? "orange" : "teal",
             title: event.ce_hours_label,
             subtitle: ce_hours_subtitle,
             href: registration_ce_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right",
             badge: ce_hours_badge(complete),
             # Amber while money is due or hours/license are still needed (nil
             # badge_classes falls back to amber in _callout_card); teal once it's
             # complete and paid.
             badge_classes: complete && !due ? "bg-teal-100 text-teal-800 border border-teal-300" : nil)
  end

  # Before the registrant has requested CE, an invite card linking to the CE page
  # where the "Request CE credit" button lives. Shown only while the request window
  # is open. Resting teal — requesting is optional, not an outstanding obligation.
  def ce_request_card
    Card.new(icon_class: "fa-solid fa-graduation-cap", color: "teal",
             title: event.ce_hours_label,
             subtitle: "Request continuing education credit",
             href: registration_ce_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right",
             badge: ce_request_badge)
  end

  # The request deadline, so a not-yet-requested registrant knows when to act —
  # e.g. "Request CE by Jul 1". No fee here (they haven't opted in and owe nothing
  # yet); the cost surfaces on the card once they've requested. Nil when the event
  # sets no request deadline.
  def ce_request_badge
    return unless event.ce_hours_request_deadline
    "Request CE by #{ce_deadline_text(event.ce_hours_request_deadline)}"
  end

  # Whether a not-yet-requested registrant can still request CE credit: no request
  # deadline set, or it hasn't passed (lenient through the end of the deadline day).
  def ce_request_open?
    deadline = event.ce_hours_request_deadline
    deadline.blank? || deadline.to_date >= Time.zone.today
  end

  def ce_hours_subtitle
    hours = registration.continuing_education_registrations.first&.hours.to_d
    return "Continuing education credit" unless hours.positive?

    "#{NumberFormatter.plain(hours)} hours"
  end

  # "$X due" for the outstanding balance once hours + license are on file (no chip
  # once paid in full); otherwise an amber chip naming what's still needed, prefixed
  # with the fee when the hours (and so the cost) are already known — e.g.
  # "$250 · License number needed". Each deadline the event sets is appended to the
  # relevant chip while still pending: the payment deadline on the amount-due chip
  # (until paid), the request deadline on the license-needed chip.
  def ce_hours_badge(complete)
    ce_registration = registration.continuing_education_registrations.first
    remaining_cents = ce_registration&.remaining_cost.to_i

    if complete
      return unless remaining_cents.positive?
      amount = MoneyFormatter.dollars_from_cents(remaining_cents)
      return "#{amount} due" if event.ce_payment_due_deadline.blank?
      return "#{amount} due by #{ce_deadline_text(event.ce_payment_due_deadline)}"
    end

    needed = ce_missing_text
    cost_cents = ce_registration&.cost_cents.to_i
    cost_cents.positive? ? "#{MoneyFormatter.dollars_from_cents(cost_cents)} · #{needed}" : needed
  end

  # Hours are set by the event now, so the only thing a requesting registrant can
  # still be missing is their license number. When the event sets a request
  # deadline, name it so the registrant knows when their license is due.
  def ce_missing_text
    return "License number needed" if event.ce_hours_request_deadline.blank?
    "License number needed by #{ce_deadline_text(event.ce_hours_request_deadline)}"
  end

  # Short month/day for a deadline shown inline on the CE card, e.g. "Jul 1".
  # in_time_zone first so a datetime deadline reports the same day it's displayed as.
  def ce_deadline_text(deadline)
    deadline.in_time_zone(Time.zone).strftime("%b %-d")
  end

  # Hidden until the event has staff — an empty roster page is nothing to link to,
  # so the card only appears once someone's been connected in the Event staff section.
  def staff_card
    return if config_gap?("staff")
    Card.new(icon_class: "fa-solid fa-people-group", color: "blue",
             title: "Meet the staff",
             subtitle: "The team for this event",
             href: registration_staff_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end

  # Shown only when the event has a videoconference URL set.
  def videoconference_card
    return if config_gap?("videoconference")
    Card.new(icon_class: "fa-solid fa-video", color: "blue",
             title: "Videoconference",
             subtitle: "Join details and add to calendar links",
             href: registration_videoconference_path(registration.slug),
             target: nil, trailing_icon: "fa-solid fa-arrow-right")
  end
end
