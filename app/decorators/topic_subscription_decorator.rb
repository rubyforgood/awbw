class TopicSubscriptionDecorator < ApplicationDecorator
  delegate_all

  # Active is a soft "live" pill; unsubscribed is a solid slate chip so the ended
  # state stays legible even when the row is de-emphasized. Slate, not red — an
  # unsubscribe is a normal choice, not an error — and a bell-slash to read as
  # "notifications off" at a glance. Pass `href:` to make the badge a link to the
  # edit page, adding a jump-link icon (mirrors the CE status badge).
  def status_badge(href: nil)
    base = "inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border px-2.5 py-0.5 text-xs font-medium"

    if active?
      classes = "bg-green-50 text-green-700 border-green-200"
      marker = h.content_tag(:span, "", class: "h-1.5 w-1.5 rounded-full bg-green-500")
      label = "Active"
    else
      classes = "bg-slate-600 text-white border-slate-600"
      marker = h.content_tag(:i, "", class: "fa-solid fa-bell-slash text-[0.65rem]")
      label = "Unsubscribed"
    end

    return h.content_tag(:span, marker + label, class: "#{base} #{classes}") unless href

    h.link_to href, class: "#{base} #{classes} transition hover:opacity-80 hover:shadow-sm",
      data: { turbo_frame: "_top" } do
      marker + label +
        h.content_tag(:i, "", class: "fa-solid fa-arrow-up-right-from-square text-[0.6rem] opacity-70")
    end
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
