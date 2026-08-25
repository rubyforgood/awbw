class ApplicationTimelineRenderer
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper

  def initialize(event)
    @event = event
  end

  def label
    subject = @event.subject
    return unless subject&.persisted?

    link_to(
      subject.timeline_label,
      Rails.application.routes.url_helpers.polymorphic_path(subject),
      data: { turbo: false },
      class: "text-sm text-blue-600 hover:underline"
    )
  end
end
