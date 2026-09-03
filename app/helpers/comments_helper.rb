module CommentsHelper
  # Human-readable label for a record a comment or communication hangs off, used
  # for both the aggregated composer's target picker and each feed row's chip so
  # the two never drift. For event-bound records we spell out the event and its
  # date so a scholarship/registration reads as a concrete thing rather than an
  # opaque id.
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
    when Affiliation then "Affiliation · #{record.person&.full_name} @ #{record.organization&.name}"
    when StaffTagging then "Staff tag · #{record.staff_tag&.name}"
    else record.class.name.underscore.humanize
    end
  end

  # Where a feed row's chip links to — the attached record's edit page, so a click
  # lands where it can actually be changed. Nil for a type with no admin edit
  # screen, which the caller renders as a plain chip.
  def record_edit_path(record)
    case record
    when Person then edit_person_path(record)
    when User then edit_user_path(record)
    when EventRegistration then edit_event_registration_path(record)
    when Scholarship then edit_scholarship_path(record)
    when ContinuingEducationRegistration then edit_continuing_education_registration_path(record)
    when TopicSubscription then edit_topic_subscription_path(record)
    when Story then edit_story_path(record)
    when StoryIdea then edit_story_idea_path(record)
    when Affiliation then edit_affiliation_path(record)
    when StaffTagging then edit_staff_tagging_path(record)
    end
  end

  # DomainTheme key driving a chip's colour, so each attached-record type reads
  # distinctly in the feed.
  def record_theme(record)
    case record
    when Person then :people
    when User then :users
    when EventRegistration then :event_registrations
    when Scholarship then :scholarships
    when ContinuingEducationRegistration then :continuing_education
    when TopicSubscription then :topic_subscriptions
    when Story then :stories
    when StoryIdea then :story_ideas
    when Affiliation then :organizations
    when StaffTagging then :people
    else :comments
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
