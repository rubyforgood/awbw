class CommentTimelineRenderer < ApplicationTimelineRenderer
  def label
    subject = @event.subject
    commentable = subject&.commentable

    text = @event.subject&.timeline_label || @event.snapshot["label"]
    return unless text
    return content_tag(:span, text, class: "text-sm text-gray-700") unless commentable&.persisted?

    link_to(text, path_for(commentable), data: { turbo: false }, class: "text-sm text-blue-600 hover:underline")
  end
end
