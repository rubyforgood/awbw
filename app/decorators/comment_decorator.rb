class CommentDecorator < ApplicationDecorator
  delegate_all

  # Human-readable label for the record this comment was left on, used as the
  # source chip on the aggregated person-comments feed. Shared with the composer's
  # target picker via CommentsHelper so the two never drift.
  def source_label
    h.commentable_label(commentable)
  end

  # Where the source chip links to — the record's admin page.
  def source_path
    case commentable
    when Person then h.person_path(commentable)
    when User then h.user_path(commentable)
    when EventRegistration then h.edit_event_registration_path(commentable)
    when Scholarship then h.scholarship_path(commentable)
    when ContinuingEducationRegistration then h.edit_continuing_education_registration_path(commentable)
    when TopicSubscription then h.edit_topic_subscription_path(commentable)
    end
  end

  # DomainTheme key driving the chip's colour, so each source type reads
  # distinctly in the feed.
  def source_theme
    case commentable
    when Person then :people
    when User then :users
    when EventRegistration then :event_registrations
    when Scholarship then :scholarships
    when ContinuingEducationRegistration then :continuing_education
    when TopicSubscription then :topic_subscriptions
    else :comments
    end
  end

  def author_name
    (updated_by || created_by)&.full_name || "System"
  end

  def timestamp
    created_at.strftime("%-m/%-d/%Y %-I:%M %p")
  end
end
