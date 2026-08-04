class TopicSubscription < ApplicationRecord
  belongs_to :person
  belongs_to :topic_subscription_type
  # Optional narrowing to a specific event (e.g. one training). Null = the topic
  # broadly.
  belongs_to :interested_event, class_name: "Event", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  before_validation :set_subscribed_at, on: :create

  validate :no_duplicate_active_subscription, on: :create

  # State is timestamp-driven: unsubscribed_at IS NULL means active.
  scope :active, -> { where(unsubscribed_at: nil) }
  scope :unsubscribed, -> { where.not(unsubscribed_at: nil) }
  scope :for_topic_type, ->(type) { where(topic_subscription_type: type) }
  scope :general, -> { where(interested_event_id: nil) }
  scope :for_event, ->(event) { where(interested_event: event) }
  scope :newest_first, -> { order(subscribed_at: :desc) }

  # Drives the subscriptions index filters: topic type, status
  # ("active"/"unsubscribed"/"general"), and a free-text match on the person.
  def self.search_by_params(params)
    scope = all
    scope = scope.where(person_id: params[:person_id]) if params[:person_id].present?
    scope = scope.for_topic_type(params[:topic_subscription_type_id]) if params[:topic_subscription_type_id].present?

    case params[:status]
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
    topic_subscription_type&.name
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
      person_id: person_id, topic_subscription_type_id: topic_subscription_type_id, interested_event_id: interested_event_id
    )
    dupes = dupes.where.not(id: id) if persisted?
    return unless dupes.exists?

    errors.add(:base, "already has an active subscription for this topic")
  end
end
