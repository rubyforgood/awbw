class TopicSubscriptionDecorator < ApplicationDecorator
  delegate_all

  def state_badge
    if active?
      classes = "bg-green-50 text-green-700 border-green-200"
      label = "Active"
    else
      classes = "bg-gray-50 text-gray-500 border-gray-200"
      label = "Unsubscribed"
    end
    h.content_tag(:span, label,
      class: "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium #{classes}")
  end

  # The specific event this subscription narrows to, or a general marker.
  def event_label
    general? ? "Any — #{topic_label.downcase}" : interested_event.title
  end
end
