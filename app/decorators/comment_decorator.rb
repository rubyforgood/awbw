class CommentDecorator < ApplicationDecorator
  include ::EventChippable
  delegate_all

  # Human-readable label for the record this comment was left on, used as the
  # source chip on the aggregated comment feeds. Profile comments name the person
  # so rows on the global feed say whose profile; every other record shares the
  # composer picker's label via CommentsHelper.
  def source_label
    return commentable.full_name if commentable.is_a?(Person)

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

  def last_editor
    updated_by || created_by
  end

  def edited_timestamp
    updated_at.strftime("%-m/%-d/%Y %-I:%M %p")
  end

  def type_chip(**options)
    content = h.safe_join([ h.content_tag(:i, "", class: "fa-solid fa-comment", "aria-hidden": "true"), "Com't" ], " ")
    chip_class = "inline-flex min-w-18 shrink-0 items-center justify-center gap-1 rounded #{DomainTheme.bg_class_for(:comments, intensity: 100)} px-1.5 py-0.5 text-xs font-medium #{DomainTheme.text_class_for(:comments, intensity: 800)}"
    h.content_tag(:span, content, { class: chip_class, title: "Comment" }.merge(options))
  end

  # The Event this comment is about, resolved through its commentable (an event
  # registration, CE registration, or scholarship). nil for non-event comments.
  def event
    event_registration&.event
  end

  private

  # Root record the shared event chip resolves a registration/event from.
  def event_chip_record
    commentable
  end
end
