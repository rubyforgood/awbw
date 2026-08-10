module CommentsHelper
  # Human-readable label for a commentable record, used for both the aggregated
  # composer's target picker and each feed row's source chip so the two never
  # drift. For event-bound records we spell out the event and its date so a
  # scholarship/registration reads as a concrete thing rather than an opaque id.
  def commentable_label(record)
    case record
    when Person then "Profile"
    when User then "User account"
    when EventRegistration then "Registration · #{event_label(record.event)}"
    when Scholarship then scholarship_label(record)
    when ContinuingEducationRegistration then "CE · #{event_label(record.event_registration.event)}"
    when TopicSubscription then "Subscription · #{record.topic_label}"
    when Story then "Story · #{record.title}"
    when StoryIdea then "Story idea · #{record.title.presence || "##{record.id}"}"
    else record.class.name.underscore.humanize
    end
  end

  private

  def event_label(event)
    return "—" unless event
    [ event.title, event.start_date&.strftime("%b %-d, %Y") ].compact_blank.join(" · ")
  end

  def scholarship_label(scholarship)
    allocatable = scholarship.allocation&.allocatable
    event =
      case allocatable
      when EventRegistration then allocatable.event
      when ContinuingEducationRegistration then allocatable.event_registration&.event
      end
    return "Scholarship ##{scholarship.id}" unless event
    "Scholarship · #{event_label(event)}"
  end
end
