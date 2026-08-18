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

  # New / Ongoing / Reinstate relative to this recipient; blank when there's no
  # program to assess.
  def program_status
    program&.program_status(object.recipient).presence || "—"
  end

  # Tailwind pill classes for the program-status badge.
  def program_status_classes
    case program&.program_status(object.recipient)
    when "Ongoing"   then "bg-blue-50 text-blue-700 border-blue-200"
    when "New"       then "bg-indigo-50 text-indigo-700 border-indigo-200"
    when "Reinstate" then "bg-purple-50 text-purple-700 border-purple-200"
    else "bg-gray-50 text-gray-500 border-gray-200"
    end
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
    "accepted" => "Signed",
    "pending" => "Pending"
  }.freeze

  AGREEMENT_STATUS_CLASSES = {
    "declined" => "bg-red-50 text-red-700 border-red-200",
    "accepted" => "bg-fuchsia-50 text-fuchsia-700 border-fuchsia-200",
    "pending" => "bg-amber-50 text-amber-700 border-amber-200"
  }.freeze

  AGREEMENT_STATUS_ICONS = {
    "declined" => "fa-solid fa-circle-xmark",
    "accepted" => "fa-solid fa-file-signature",
    "pending" => "fa-solid fa-file-signature"
  }.freeze

  def agreement_status_label = AGREEMENT_STATUS_LABELS.fetch(object.agreement_response_status)
  def agreement_status_classes = AGREEMENT_STATUS_CLASSES.fetch(object.agreement_response_status)
  def agreement_status_icon = AGREEMENT_STATUS_ICONS.fetch(object.agreement_response_status)

  # The agreement-status pill every surface that lists a scholarship renders, so
  # the three states read the same everywhere: Declined (red), Signed (fuchsia),
  # Pending (amber). Compact surfaces only need to flag the exception, so
  # pending/signed render nothing unless `all_states:`. `prefix:` reads it as
  # "Agreement declined" where the pill sits next to a tasks pill.
  def agreement_status_badge(all_states: false, prefix: false, icon_size: "text-xs")
    return unless all_states || object.agreement_declined?

    label = prefix ? "Agreement #{agreement_status_label.downcase}" : agreement_status_label
    h.render "shared/badge", label: label, classes: agreement_status_classes,
             icon: [ agreement_status_icon, icon_size ].compact_blank.join(" ")
  end
end
