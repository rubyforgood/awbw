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

    @program = object.recipient&.facilitator_organization
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
    when "New"       then "bg-green-50 text-green-700 border-green-200"
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
end
