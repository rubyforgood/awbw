module CommentsHelper
  FEED_FILTER_FORM_ID = "comments-and-communications-filters"
  FEED_RETURN_TO = "comments_and_communications".freeze

  # The full feed narrowed to one comment or communication, carrying the person
  # it's about and the record to return to for the eyebrow.
  def feed_entry_path(entry, person: nil, return_to: nil)
    id_param = entry.is_a?(Comment) ? :comment_id : :notification_id
    comments_and_communications_path({
      person_id: person&.id,
      id_param => entry.id,
      return_to_type: return_to&.model_name&.name,
      return_to_id: return_to&.id
    }.compact)
  end

  # A person chip's edit link, remembering which feed (a person's, or everyone's)
  # to return to.
  def feed_person_edit_path(person, feed_person: nil)
    edit_person_path(person, { return_to: FEED_RETURN_TO, feed_person_id: feed_person&.id }.compact)
  end

  def feed_return_path
    comments_and_communications_path({ person_id: params[:feed_person_id].presence }.compact)
  end

  # Names who a row on the everyone feed is about. A communication's contact
  # falls back to their raw email when no person is on file.
  def feed_person_chip(entry)
    if entry.is_a?(Comment)
      person = entry.decorate.about_person
      email = nil
    else
      person = entry.decorate.contact_person
      email = entry.recipient_email
    end
    return if person.nil? && email.blank?

    render "comments_and_communications/about_person_chip", person: person, email: email
  end

  # Stimulus wiring for a feed row the chevron and "Expand/Collapse all" toggle.
  # clamp: a one-line row unclamped to show the full entry; otherwise a full row
  # whose body hides on collapse. key lets expandable-cards remember a row toggled
  # on its own across a results reload.
  def expandable_feed_row_data(clamp: true, key: nil)
    data = {
      controller: "expandable-card",
      expandable_card_expanded_value: !clamp,
      action: "expandable-cards:expandAll@window->expandable-card#expand expandable-cards:collapseAll@window->expandable-card#collapse"
    }
    data[:expandable_card_collapsed_class] = "line-clamp-2" if clamp
    data[:expandable_card_key_value] = key if key
    data
  end

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
    when FormSubmission then form_submission_label(record)
    when Story then "Story · #{record.title}"
    when StoryIdea then "Story idea · #{record.title.presence || "##{record.id}"}"
    when Affiliation then "Affiliation · #{record.person&.full_name} @ #{record.organization&.name}"
    when StaffTagging then "Staff tag · #{record.staff_tag&.name}"
    when Report then "Report · #{record.title}"
    when WorkshopIdea then "Workshop idea · #{record.title}"
    when WorkshopLog then "Workshop log · #{record.title}"
    when WorkshopVariationIdea then "Workshop variation idea · #{record.title}"
    when WorkshopVariation then "Workshop variation · #{record.title}"
    when Grant then "Grant · #{record.name}"
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
    when FormSubmission then form_submission_path(record)
    when Story then edit_story_path(record)
    when StoryIdea then edit_story_idea_path(record)
    when Affiliation then edit_affiliation_path(record)
    when StaffTagging then edit_staff_tagging_path(record)
    when Report then edit_report_path(record)
    when WorkshopIdea then edit_workshop_idea_path(record)
    when WorkshopLog then edit_workshop_log_path(record)
    when WorkshopVariationIdea then edit_workshop_variation_idea_path(record)
    when WorkshopVariation then edit_workshop_variation_path(record)
    when Grant then edit_grant_path(record)
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
    when FormSubmission then :forms
    when Story then :stories
    when StoryIdea then :story_ideas
    when Affiliation then :organizations
    when StaffTagging then :people
    when Report then :reports
    when WorkshopIdea then :workshop_ideas
    when WorkshopLog then :workshop_logs
    when WorkshopVariationIdea then :workshop_variation_ideas
    when WorkshopVariation then :workshop_variations
    when Grant then :grants
    else :comments
    end
  end

  # A comment's "Logged against" picker: the person's targets with the comment's
  # current record selected, listed first when it isn't one of those targets.
  def comment_target_options(comment, targets)
    record = comment.commentable
    current = targets.find { |target| target[:gid] == record.to_gid_param } ||
      { label: commentable_label(record), sgid: record.to_sgid.to_s }
    options = targets.include?(current) ? targets : [ current, *targets ]
    options_for_select(options.map { |target| [ target[:label], target[:sgid] ] }, current[:sgid])
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

  def form_submission_label(submission)
    name = submission.form&.display_name.presence || "##{submission.id}"
    event = submission.resolved_event
    "Form · #{event ? "#{name} · #{event_label(event)}" : name}"
  end
end
