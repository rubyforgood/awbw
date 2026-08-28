class NestedRecordTimelineRenderer < ApplicationTimelineRenderer
  # Nested records live on the owner's page (Person or Organization),
  # so link back to the owner with context like "on Amy User".
  # A destroyed record's row is gone, so fall back to the snapshot label
  # and render an unlinked span with "from Amy User" context.
  def label
    subject = @event.subject
    text = subject&.timeline_label || @event.snapshot["label"]
    return unless text
    return content_tag(:span, text, class: "text-sm text-gray-700") unless @owner&.persisted?

    preposition = @event.action == "destroyed" ? "from" : "on"
    context = "#{text} #{preposition} #{@owner.timeline_label}"
    return content_tag(:span, context, class: "text-sm text-gray-700") if subject.nil?

    link_to(context, routes.polymorphic_path(@owner), data: { turbo: false }, class: "text-sm text-blue-600 hover:underline")
  end
end
