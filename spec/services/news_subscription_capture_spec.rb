require "rails_helper"

RSpec.describe NewsSubscriptionCapture do
  let(:person) { create(:person) }

  it "creates an active News subscription carrying the source" do
    create(:topic_subscription_type, name: "News")

    expect {
      described_class.call(person: person, source: "2026-06-23 Facilitator Training registration")
    }.to change { person.topic_subscriptions.count }.by(1)

    subscription = person.topic_subscriptions.last
    expect(subscription.topic_subscription_type.key).to eq("news")
    expect(subscription.source).to eq("2026-06-23 Facilitator Training registration")
    expect(subscription).to be_active
  end

  it "does nothing when the person already has an active News subscription" do
    news = create(:topic_subscription_type, name: "News")
    create(:topic_subscription, person: person, topic_subscription_type: news, source: "Earlier")

    expect {
      described_class.call(person: person, source: "Later registration")
    }.not_to change { person.topic_subscriptions.count }

    expect(person.topic_subscriptions.sole.source).to eq("Earlier")
  end

  it "re-subscribes after an earlier unsubscribe" do
    news = create(:topic_subscription_type, name: "News")
    create(:topic_subscription, :unsubscribed, person: person, topic_subscription_type: news, source: "Earlier")

    expect {
      described_class.call(person: person, source: "Later registration")
    }.to change { person.topic_subscriptions.active.count }.by(1)
  end

  it "is a no-op when no News topic exists" do
    expect {
      described_class.call(person: person, source: "Anywhere")
    }.not_to change { TopicSubscription.count }
  end
end
