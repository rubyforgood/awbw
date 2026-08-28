class CommentDecorator < ApplicationDecorator
  delegate_all

  # Human-readable label for the record this comment was left on, used as the
  # source chip on the aggregated person-comments feed. Shared with the composer's
  # target picker via CommentsHelper so the two never drift.
  def source_label
    h.commentable_label(commentable)
  end

  # Where the source chip links to — the record's edit page, shared with the
  # communication chips via CommentsHelper so both feeds behave the same.
  def source_path
    h.record_edit_path(commentable)
  end

  def source_theme
    h.record_theme(commentable)
  end

  def author_name
    (updated_by || created_by)&.full_name || "System"
  end

  def timestamp
    created_at.strftime("%-m/%-d/%Y %-I:%M %p")
  end
end
