class TrainingInterestDecorator < ApplicationDecorator
  delegate_all

  STATUS_CLASSES = {
    "open" => "bg-blue-50 text-blue-700 border-blue-200",
    "converted" => "bg-green-50 text-green-700 border-green-200",
    "closed" => "bg-gray-50 text-gray-500 border-gray-200"
  }.freeze

  def status_badge
    classes = STATUS_CLASSES.fetch(status, "bg-gray-50 text-gray-500 border-gray-200")
    h.content_tag(:span, status_label,
      class: "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium #{classes}")
  end

  # What the interest points at: a specific scheduled training, or the general
  # "future trainings" list.
  def target_label
    general? ? "General — future trainings" : event.title
  end
end
