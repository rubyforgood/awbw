# Gathers every comment connected to a person into a single newest-first feed —
# their own profile comments plus the comments left on the records that hang off
# them: event registrations, scholarships, CE registrations, the stories and
# story ideas they're credited on, and their login account. Returns one
# ActiveRecord::Relation of Comment so callers can filter, paginate, and preload
# uniformly. Payments carry no comments, so they never appear here.
class PersonCommentAggregator
  # commentable_type => class, in the order sources are surfaced. Kept as strings
  # so the query never has to instantiate the classes.
  SOURCE_TYPES = %w[ Person EventRegistration Scholarship ContinuingEducationRegistration TopicSubscription Story StoryIdea User ].freeze

  def initialize(person)
    @person = person
  end

  def comments
    scopes = [
      scope_for("Person", [ @person.id ]),
      scope_for("EventRegistration", registration_ids),
      scope_for("Scholarship", scholarship_ids),
      scope_for("ContinuingEducationRegistration", ce_registration_ids),
      scope_for("TopicSubscription", topic_subscription_ids),
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

  # Stories where this person is the credited author — mirrors Story#author_person:
  # the explicit author, or the creating user's person when no explicit author is set.
  def story_ids
    Story.where(author_id: person.id)
         .or(Story.where(author_id: nil, created_by_id: user_ids))
         .ids
  end

  # Story ideas carry no explicit author, so the creating user's person is the credit.
  def story_idea_ids
    StoryIdea.where(created_by_id: user_ids).ids
  end

  def user_ids
    person.user ? [ person.user.id ] : []
  end
end
