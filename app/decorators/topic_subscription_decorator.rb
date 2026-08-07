class TopicSubscriptionDecorator < ApplicationDecorator
  delegate_all

  # Active is a soft "live" pill; unsubscribed is a solid slate chip so the ended
  # state stays legible even when the row is de-emphasized. Slate, not red — an
  # unsubscribe is a normal choice, not an error — and a bell-slash to read as
  # "notifications off" at a glance. Pass `href:` to make the badge a link to the
  # edit page, adding a jump-link icon (mirrors the CE status badge).
  def status_badge(href: nil)
    icon = nil
    icon_html = nil

    if active?
      classes = "bg-green-50 text-green-700 border-green-200"
      icon_html = h.content_tag(:span, "", class: "h-1.5 w-1.5 rounded-full bg-green-500")
      label = "Active"
    else
      classes = "bg-slate-600 text-white border-slate-600"
      icon = "fa-solid fa-bell-slash text-[0.65rem]"
      label = "Unsubscribed"
    end

    h.render "shared/badge", label: label, classes: classes, icon: icon, icon_html: icon_html, href: href
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
