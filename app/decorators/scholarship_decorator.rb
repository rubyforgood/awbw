class ScholarshipDecorator < ApplicationDecorator
  delegate_all

  def recipient_name
    object.recipient&.full_name.presence || "Unknown recipient"
  end

  def amount
    h.number_to_currency(object.amount_dollars)
  end

  # The organization the recipient facilitates for — the "program" the
  # scholarship serves. Memoized so the row's program/location/status cells share
  # one lookup.
  def program
    return @program if defined?(@program)

    @program = object.recipient&.program_organization
  end

  def program_name
    program&.name.presence || "—"
  end

  def program_location
    program&.program_location.presence || "—"
  end

  # The program's New / Ongoing / Reinstated verdict, anchored on the start date of
  # the training this award paid for — so each row is judged at its own event
  # rather than at one page-wide date. Falls back to the year anchor when the award
  # has no registration behind it. One rule for every surface (ADR-0001 D4).
  def facilitator_program_status
    return @facilitator_program_status if defined?(@facilitator_program_status)

    @facilitator_program_status = program&.facilitator_program_status(as_of: object.event&.start_date)
  end

  def program_status
    facilitator_program_status&.label.presence || "—"
  end

  # Tailwind pill classes for the program-status badge.
  def program_status_classes
    OrganizationDecorator.program_status_classes(facilitator_program_status&.status) ||
      "bg-gray-50 text-gray-500 border-gray-200"
  end

  # Hover text naming the anchor date and the reasoning, worded exactly like the
  # org profile's per-event chips.
  def program_status_explanation
    facilitator_program_status&.explanation
  end

  # The facilitator-training event(s) the recipient attended ("TAC"); titles
  # joined when more than one, em dash when none.
  def training_label
    titles = object.recipient&.completed_facilitator_trainings.to_a.filter_map(&:title)
    titles.any? ? titles.join(", ") : "—"
  end

  def tasks_completed?
    object.tasks_completed?
  end

  def agreement_signed?
    object.agreement_signed?
  end

  def agreement_declined?
    object.agreement_declined?
  end

  AGREEMENT_STATUS_LABELS = {
    "declined" => "Declined",
    "accepted" => "Accepted",
    "pending" => "Offered",
    "support_requested" => "Requested"
  }.freeze

  AGREEMENT_STATUS_CLASSES = {
    "declined" => "bg-red-50 text-red-700 border-red-200",
    "accepted" => "bg-fuchsia-50 text-fuchsia-700 border-fuchsia-200",
    "pending" => "bg-amber-50 text-amber-700 border-amber-200",
    "support_requested" => "bg-sky-50 text-sky-700 border-sky-200"
  }.freeze

  AGREEMENT_STATUS_ICONS = {
    "declined" => "fa-solid fa-circle-xmark",
    "accepted" => "fa-solid fa-file-signature",
    "pending" => "fa-solid fa-file-signature",
    "support_requested" => "fa-solid fa-hand-holding-dollar"
  }.freeze

  def agreement_status_label = AGREEMENT_STATUS_LABELS.fetch(object.agreement_response_status)
  def agreement_status_classes = AGREEMENT_STATUS_CLASSES.fetch(object.agreement_response_status)
  def agreement_status_icon = AGREEMENT_STATUS_ICONS.fetch(object.agreement_response_status)

  # The agreement-status pill every surface that lists a scholarship renders, so
  # the states read the same everywhere: Declined (red), Accepted (fuchsia),
  # Offered (amber), Requested (sky). Compact surfaces only flag the states that
  # need follow-up, so offered/accepted render nothing unless `all_states:` while
  # declined and requested always show. `prefix:` reads it as "Agreement declined"
  # where the pill sits next to a tasks pill.
  def agreement_status_badge(all_states: false, prefix: false, icon_size: "text-xs")
    return unless all_states || object.agreement_declined? || object.agreement_support_requested?

    label = prefix ? "Agreement #{agreement_status_label.downcase}" : agreement_status_label
    h.render "shared/badge", label: label, classes: agreement_status_classes,
             icon: [ agreement_status_icon, icon_size ].compact_blank.join(" ")
  end
end
