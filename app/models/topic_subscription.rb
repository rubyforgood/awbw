class TopicSubscription < ApplicationRecord
  # Topics a person can subscribe to. Add new list topics here.
  TOPICS = %w[ facilitator_trainings news resources ].freeze
  TOPIC_LABELS = {
    "facilitator_trainings" => "Facilitator trainings",
    "news" => "News",
    "resources" => "Resources"
  }.freeze
  # The registration form's `interested_in_more` answer ("upcoming trainings or
  # resources?") backfills/auto-captures into this topic (see follow-up).
  INTERESTED_IN_MORE_TOPIC = "facilitator_trainings"

  belongs_to :person
  # Optional narrowing to a specific event (e.g. one training). Null = the topic
  # broadly.
  belongs_to :interested_event, class_name: "Event", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  before_validation :set_subscribed_at, on: :create

  validates :topic, inclusion: { in: TOPICS }, allow_nil: false
  validate :no_duplicate_active_subscription, on: :create

  # State is timestamp-driven: unsubscribed_at IS NULL means active.
  scope :active, -> { where(unsubscribed_at: nil) }
  scope :unsubscribed, -> { where.not(unsubscribed_at: nil) }
  scope :for_topic, ->(topic) { where(topic: topic) }
  scope :general, -> { where(interested_event_id: nil) }
  scope :for_event, ->(event) { where(interested_event: event) }
  scope :newest_first, -> { order(subscribed_at: :desc) }

  # Drives the subscriptions index filters: topic, state
  # ("active"/"unsubscribed"/"general"), and a free-text match on the person.
  def self.search_by_params(params)
    scope = all
    scope = scope.for_topic(params[:topic]) if TOPICS.include?(params[:topic].to_s)

    case params[:state]
    when "active" then scope = scope.active
    when "unsubscribed" then scope = scope.unsubscribed
    when "general" then scope = scope.general
    end

    if params[:q].present?
      term = "%#{params[:q].to_s.strip.downcase}%"
      scope = scope.joins(:person).where(
        "LOWER(people.first_name) LIKE :t OR LOWER(people.last_name) LIKE :t OR " \
        "LOWER(CONCAT(people.first_name, ' ', people.last_name)) LIKE :t OR LOWER(people.email) LIKE :t",
        t: term
      )
    end
    scope
  end

  def active?
    unsubscribed_at.nil?
  end

  # Subscription to the topic broadly, not narrowed to a specific event.
  def general?
    interested_event_id.nil?
  end

  def topic_label
    TOPIC_LABELS.fetch(topic, topic.humanize)
  end

  def unsubscribe!
    update!(unsubscribed_at: Time.current) if active?
  end

  def resubscribe!
    update!(unsubscribed_at: nil)
  end

  # The person's registrations for facilitator-training events, shown in the
  # index's registrations column. Selected in memory so the controller's eager
  # load (person → event_registrations → event) prevents an N+1.
  def person_facilitator_training_registrations
    person.event_registrations.select { |registration| registration.event&.facilitator_training? }
  end

  private

  def set_subscribed_at
    self.subscribed_at ||= Time.current
  end

  # One active subscription per (person, topic, event) — a general subscription
  # (null event) and an event-specific one are distinct. Re-subscribing after an
  # unsubscribe is allowed.
  def no_duplicate_active_subscription
    return unless active?

    dupes = TopicSubscription.active.where(
      person_id: person_id, topic: topic, interested_event_id: interested_event_id
    )
    dupes = dupes.where.not(id: id) if persisted?
    return unless dupes.exists?

    errors.add(:base, "already has an active subscription for this topic")
  end
end
