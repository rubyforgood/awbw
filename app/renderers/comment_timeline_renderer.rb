class CommentTimelineRenderer < ApplicationTimelineRenderer
  def label
    commentable = @event.subject&.commentable
    return @event.subject&.timeline_label unless commentable&.persisted?

    link_to(
      @event.subject.timeline_label,
      Rails.application.routes.url_helpers.polymorphic_path(commentable),
      data: { turbo: false },
      class: "text-sm text-blue-600 hover:underline"
    )
  end
end
