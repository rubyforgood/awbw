module TopicSubscriptionHelper
  # Where a subscription form came from, keyed by the `return_to` param its
  # originating link set (an event's Forms menu, a person's associated records,
  # or the subscriptions index). One source of truth for the eyebrow, the form's
  # Cancel button, and the controller's post-save redirect so all three agree.
  # Returns [ label, path ]; an unrecognized origin, or one missing the id it
  # needs, falls back to the subscriptions index.
  def topic_subscription_return_link
    label, path = case params[:return_to]
    when "dashboard"
      [ "← Dashboard", (dashboard_event_path(params[:event_id]) if params[:event_id].present?) ]
    when "registrants"
      [ "← Registrants", (registrants_event_path(params[:event_id]) if params[:event_id].present?) ]
    when "person"
      person = Person.find_by(id: params[:person_id])
      [ "← #{person&.full_name || "Person"}", (edit_person_path(person) if person) ]
    end

    [ label || "← Subscriptions", path || topic_subscriptions_path ]
  end

  def topic_subscription_return_path
    topic_subscription_return_link.last
  end

  # The index filters carried into the email-addresses page, described as
  # [ label, value ] pairs for the grey chips at the top. Only filters actually
  # applied are returned, so an unfiltered list shows no chips.
  def topic_subscription_applied_filters(params)
    filters = []

    if params[:person_id].present?
      person = Person.find_by(id: params[:person_id])
      filters << [ "Person", person&.full_name || "Unknown" ]
    end

    if params[:topic_subscription_type_id].present?
      topic = TopicSubscriptionType.find_by(id: params[:topic_subscription_type_id])
      filters << [ "Topic", topic&.name || "Unknown" ]
    end

    status_labels = { "active" => "Active", "unsubscribed" => "Unsubscribed", "general" => "General (no event)" }
    filters << [ "Status", status_labels[params[:status]] ] if status_labels.key?(params[:status])

    filters << [ "Search", "“#{params[:q].to_s.strip}”" ] if params[:q].present?

    filters
  end
end
