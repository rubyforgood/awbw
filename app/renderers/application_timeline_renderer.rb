class ApplicationTimelineRenderer
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper

  def initialize(event, owner: nil)
    @event = event
    @owner = owner
  end

  def label
    subject = @event.subject
    return content_tag(:span, @event.snapshot["label"], class: "text-sm text-gray-700") if subject.nil?
    return unless subject.persisted?

    link_to(
      subject.timeline_label,
      path_for(subject),
      data: { turbo: false },
      class: "text-sm text-blue-600 hover:underline"
    )
  end

  private

  def routes
    Rails.application.routes.url_helpers
  end

  def path_for(record)
    routes.polymorphic_path(record)
  end
end
