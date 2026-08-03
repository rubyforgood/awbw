require "rails_helper"

RSpec.describe TopicSubscription, type: :model do
  describe "validations" do
    it "requires a topic in TOPICS" do
      subscription = build(:topic_subscription, topic: "bogus")
      expect(subscription).not_to be_valid
      expect(subscription.errors[:topic]).to be_present
    end

    it "rejects a second active subscription for the same person, topic, and general scope" do
      person = create(:person)
      create(:topic_subscription, person: person, topic: "facilitator_trainings", interested_event: nil)

      dupe = build(:topic_subscription, person: person, topic: "facilitator_trainings", interested_event: nil)
      expect(dupe).not_to be_valid
      expect(dupe.errors[:base]).to include("already has an active subscription for this topic")
    end

    it "allows the same person to subscribe to different topics" do
      person = create(:person)
      create(:topic_subscription, person: person, topic: "facilitator_trainings")

      news = build(:topic_subscription, person: person, topic: "news")
      expect(news).to be_valid
    end

    it "allows a general and an event-specific subscription for the same topic" do
      person = create(:person)
      create(:topic_subscription, person: person, topic: "facilitator_trainings", interested_event: nil)

      specific = build(:topic_subscription, person: person, topic: "facilitator_trainings", interested_event: create(:event))
      expect(specific).to be_valid
    end

    it "allows re-subscribing after an unsubscribe" do
      person = create(:person)
      create(:topic_subscription, :unsubscribed, person: person, topic: "facilitator_trainings", interested_event: nil)

      fresh = build(:topic_subscription, person: person, topic: "facilitator_trainings", interested_event: nil)
      expect(fresh).to be_valid
    end
  end

  describe "subscribed_at" do
    it "defaults to now on create" do
      expect(create(:topic_subscription).subscribed_at).to be_present
    end

    it "preserves an explicit timestamp (backfill)" do
      time = 2.years.ago.change(usec: 0)
      subscription = create(:topic_subscription, subscribed_at: time)
      expect(subscription.subscribed_at).to be_within(1.second).of(time)
    end
  end

  describe "state" do
    it "is active when unsubscribed_at is nil" do
      expect(build(:topic_subscription)).to be_active
    end

    it "unsubscribe! stamps unsubscribed_at" do
      subscription = create(:topic_subscription)
      subscription.unsubscribe!
      expect(subscription.reload).not_to be_active
      expect(subscription.unsubscribed_at).to be_present
    end

    it "resubscribe! clears unsubscribed_at" do
      subscription = create(:topic_subscription, :unsubscribed)
      subscription.resubscribe!
      expect(subscription.reload).to be_active
    end
  end

  describe "#general?" do
    it "is true without an event and false with one" do
      expect(build(:topic_subscription, interested_event: nil)).to be_general
      expect(build(:topic_subscription, interested_event: create(:event))).not_to be_general
    end
  end

  describe "scopes" do
    it "filters by state, topic, and generality" do
      active = create(:topic_subscription, topic: "facilitator_trainings", interested_event: nil)
      gone = create(:topic_subscription, :unsubscribed, person: create(:person), topic: "facilitator_trainings")
      news = create(:topic_subscription, :news, person: create(:person))
      event = create(:event)
      specific = create(:topic_subscription, person: create(:person), topic: "facilitator_trainings", interested_event: event)

      expect(described_class.active).to include(active, specific, news)
      expect(described_class.active).not_to include(gone)
      expect(described_class.unsubscribed).to contain_exactly(gone)
      expect(described_class.for_topic("news")).to contain_exactly(news)
      expect(described_class.general).to include(active)
      expect(described_class.general).not_to include(specific)
      expect(described_class.for_event(event)).to contain_exactly(specific)
    end
  end
end
