module TopicSubscriptionHelper
  # The filters the subscriptions index applies. They ride along on links off the
  # index and back through the form so a return trip lands on the same filtered
  # list rather than the bare index.
  INDEX_FILTER_KEYS = %w[person_id topic_subscription_type_id status page].freeze

  # Where a subscription form came from, keyed by the `return_to` param its
  # originating link set (the subscriptions index, an event's Forms menu, or a
  # person's associated records). One source of truth for the eyebrow, the form's
  # Cancel button, and the controller's post-save redirect so all three agree.
  # Returns [ label, path ]; an unrecognized origin, or one missing the id it
  # needs, falls back to the subscriptions index.
  def topic_subscription_return_link
    label, path = case params[:return_to]
    when "index"
      [ "← Subscriptions", topic_subscriptions_path(topic_subscription_index_filters) ]
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

  # The filters currently narrowing the index, for links that leave it.
  def topic_subscription_index_filters
    INDEX_FILTER_KEYS.index_with { |key| params[key] }.compact_blank.symbolize_keys
  end

  # Everything the destination needs to rebuild the back link: the origin marker
  # plus the ids and filters that origin's path is built from. Re-emitted as the
  # form's hidden fields and carried on the edit page's action buttons, so the
  # redirect after a save, unsubscribe, or remove matches the eyebrow.
  def topic_subscription_return_params
    topic_subscription_index_filters
      .merge(return_to: params[:return_to], event_id: params[:event_id])
      .compact_blank
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

    filters
  end
end
