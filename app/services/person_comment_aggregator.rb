# Gathers every comment connected to a person into a single newest-first feed —
# their own profile comments plus the comments left on the records that hang off
# them: affiliations, event registrations, scholarships, CE registrations, form
# submissions, staff tags, monthly reports, workshop ideas/logs/variations/variation
# ideas, the stories and story ideas they're credited on, and their login account.
# Returns one ActiveRecord::Relation of Comment so callers can filter, paginate,
# and preload uniformly. Payments carry no comments, so they never appear here.
class PersonCommentAggregator
  # commentable_type => class, in the order sources are surfaced. Kept as strings
  # so the query never has to instantiate the classes. "Report" keys MonthlyReport
  # comments — STI stores the base class name.
  SOURCE_TYPES = %w[ Person Affiliation EventRegistration Scholarship ContinuingEducationRegistration TopicSubscription FormSubmission StaffTagging Report WorkshopIdea WorkshopLog WorkshopVariation WorkshopVariationIdea Story StoryIdea User ].freeze

  def initialize(person)
    @person = person
  end

  def comments
    scopes = [
      scope_for("Person", [ @person.id ]),
      scope_for("Affiliation", affiliation_ids),
      scope_for("EventRegistration", registration_ids),
      scope_for("Scholarship", scholarship_ids),
      scope_for("ContinuingEducationRegistration", ce_registration_ids),
      scope_for("TopicSubscription", topic_subscription_ids),
      scope_for("FormSubmission", form_submission_ids),
      scope_for("StaffTagging", staff_tagging_ids),
      scope_for("Report", monthly_report_ids),
      scope_for("WorkshopIdea", workshop_idea_ids),
      scope_for("WorkshopLog", workshop_log_ids),
      scope_for("WorkshopVariation", workshop_variation_ids),
      scope_for("WorkshopVariationIdea", workshop_variation_idea_ids),
      scope_for("Story", story_ids),
      scope_for("StoryIdea", story_idea_ids),
      scope_for("User", user_ids)
    ]
    scopes.reduce { |combined, scope| combined.or(scope) }
      .includes(:commentable, :created_by, :updated_by)
      .newest_first
  end

  private

  attr_reader :person

  def scope_for(type, ids)
    Comment.where(commentable_type: type, commentable_id: ids)
  end

  def affiliation_ids
    person.affiliations.ids
  end

  def registration_ids
    @registration_ids ||= person.event_registrations.ids
  end

  def scholarship_ids
    person.scholarships.ids
  end

  def ce_registration_ids
    ContinuingEducationRegistration.where(event_registration_id: registration_ids).ids
  end

  def topic_subscription_ids
    person.topic_subscriptions.ids
  end

  def form_submission_ids
    person.form_submissions.ids
  end

  def staff_tagging_ids
    person.staff_taggings.ids
  end

  def monthly_report_ids
    PersonCreditedRecords.monthly_reports(person).ids
  end

  def workshop_idea_ids
    PersonCreditedRecords.workshop_ideas(person).ids
  end

  def workshop_log_ids
    PersonCreditedRecords.workshop_logs(person).ids
  end

  def workshop_variation_ids
    PersonCreditedRecords.workshop_variations(person).ids
  end

  def workshop_variation_idea_ids
    PersonCreditedRecords.workshop_variation_ideas(person).ids
  end

  # Stories the person is credited on — the explicit author, or the creating
  # user's person when no explicit author is set (AuthorCreditable#author_person).
  # PeopleHelper#person_record_targets offers the same set as picker targets.
  def story_ids
    PersonCreditedRecords.stories(person).ids
  end

  # Story ideas carry no explicit author, so the creating user's person is the credit.
  def story_idea_ids
    PersonCreditedRecords.story_ideas(person).ids
  end

  def user_ids
    person.user ? [ person.user.id ] : []
  end
end
