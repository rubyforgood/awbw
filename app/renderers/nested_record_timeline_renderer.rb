class NestedRecordTimelineRenderer < ApplicationTimelineRenderer
  # Nested records live on the owner's page (Person or Organization),
  # so link back to the owner with context like "on Amy User".
  def label
    subject = @event.subject
    text = subject&.timeline_label
    return unless text
    return content_tag(:span, text, class: "text-sm text-gray-700") unless @owner&.persisted?

    context = "#{text} on #{@owner.timeline_label}"
    link_to(context, routes.polymorphic_path(@owner), data: { turbo: false }, class: "text-sm text-blue-600 hover:underline")
  end
end
