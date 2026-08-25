class NotificationTimelineRenderer < ApplicationTimelineRenderer
  def label
    noticeable = @event.subject&.noticeable
    return @event.subject&.timeline_label unless noticeable&.persisted?

    link_to(
      @event.subject.timeline_label,
      Rails.application.routes.url_helpers.polymorphic_path(noticeable),
      data: { turbo: false },
      class: "text-sm text-blue-600 hover:underline"
    )
  end
end
