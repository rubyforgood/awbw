class TopicSubscription < ApplicationRecord
  belongs_to :person
  belongs_to :topic_subscription_type
  # Optional narrowing to a specific event (e.g. one training). Null = the topic
  # broadly.
  belongs_to :interested_event, class_name: "Event", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  before_validation :set_subscribed_at, on: :create
  before_validation :clear_event_for_non_event_topic

  validate :no_duplicate_active_subscription

  # State is timestamp-driven: unsubscribed_at IS NULL means active.
  scope :active, -> { where(unsubscribed_at: nil) }
  scope :unsubscribed, -> { where.not(unsubscribed_at: nil) }
  scope :for_topic_type, ->(type) { where(topic_subscription_type: type) }
  scope :general, -> { where(interested_event_id: nil) }
  scope :for_event, ->(event) { where(interested_event: event) }
  scope :newest_first, -> { order(subscribed_at: :desc) }

  # Drives the subscriptions index filters: person, topic type, and status
  # ("active"/"unsubscribed" — the two the segmented toggle emits). The person
  # filter is an exact id — the index picks people through the remote-select
  # search, so there's no free-text name matching to do here. Generality is a
  # separate axis (see `general`), not a status, so it isn't folded in here.
  def self.search_by_params(params)
    scope = all
    scope = scope.where(person_id: params[:person_id]) if params[:person_id].present?
    scope = scope.for_topic_type(params[:topic_subscription_type_id]) if params[:topic_subscription_type_id].present?

    case params[:status]
    when "active" then scope = scope.active
    when "unsubscribed" then scope = scope.unsubscribed
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

  # Not a bang method: reviving this row can collide with an active subscription
  # for the same (person, topic, event) created since the unsubscribe, so callers
  # have to handle a false return.
  def resubscribe
    update(unsubscribed_at: nil)
  end

  # The person's registrations for facilitator-training events, shown in the
  # index's registrations column. Selected in memory so the controller's eager
  # load (person → event_registrations → event) prevents an N+1.
  def person_facilitator_training_registrations
    person.event_registrations.select { |registration| registration.event&.facilitator_training? }
  end

  # The person is already enrolled in the very event this subscription names, so
  # the interest has been answered and there's nothing left to invite them to. A
  # general subscription names no event, so it never counts as answered — being
  # registered for one training says nothing about wanting to hear about the
  # next. Selected in memory to reuse the same eager load as the column above.
  def interest_already_answered?
    return false if general?

    person.event_registrations.any? { |registration| registration.event_id == interested_event_id }
  end

  private

  def set_subscribed_at
    self.subscribed_at ||= Time.current
  end

  # Topics without an event selector (e.g. News) have no event dimension, so any
  # stray event is dropped rather than modeled as an N/A at the subscription level.
  def clear_event_for_non_event_topic
    self.interested_event_id = nil unless topic_subscription_type&.event_selector?
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
