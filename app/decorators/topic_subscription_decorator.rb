class TopicSubscriptionDecorator < ApplicationDecorator
  delegate_all

  def status_badge
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

  # The specific event this subscription narrows to, "Any — <topic>" for a broad
  # subscription to an event-oriented topic, or "N/A" for topics with no event
  # dimension (e.g. News).
  def event_label
    return interested_event.title if interested_event
    topic_subscription_type&.event_selector? ? "Any — #{topic_label.downcase}" : "N/A"
  end

  # A broad ("Any") subscription to an event-oriented topic — the case the index
  # flags with a layers icon.
  def general_event_scope?
    general? && topic_subscription_type&.event_selector?
  end
end
