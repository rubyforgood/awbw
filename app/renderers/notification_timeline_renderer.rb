class NotificationTimelineRenderer < ApplicationTimelineRenderer
  def label
    subject = @event.subject
    noticeable = subject&.noticeable

    text = @event.subject&.timeline_label || @event.snapshot["label"]
    return unless text
    return content_tag(:span, text, class: "text-sm text-gray-700") unless noticeable&.persisted?

    link_to(text, path_for(noticeable), data: { turbo: false }, class: "text-sm text-blue-600 hover:underline")
  end
end
