class NewsSubscriptionCapture
  def self.call(...)
    new(...).call
  end

  def initialize(person:, source:)
    @person = person
    @source = source
  end

  # The successor to the retired person-level mailing-list consent flag: an
  # affirmative communication-consent answer becomes an active subscription to
  # the general-mailing-list (News) topic, carrying where it came from as its
  # source. Idempotent — a person with an active News subscription is left
  # alone, and a missing News topic is a no-op.
  def call
    topic = TopicSubscriptionType.news
    return unless topic
    return if @person.topic_subscriptions.active.for_topic_type(topic).exists?

    @person.topic_subscriptions.create!(topic_subscription_type: topic, source: @source)
  end
end
