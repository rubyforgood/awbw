require "rails_helper"

RSpec.describe TopicSubscription, type: :model do
  let(:trainings) { create(:topic_subscription_type, :facilitator_trainings) }

  describe "validations" do
    it "requires a topic subscription type" do
      subscription = build(:topic_subscription, topic_subscription_type: nil)
      expect(subscription).not_to be_valid
      expect(subscription.errors[:topic_subscription_type]).to be_present
    end

    it "rejects a second active subscription for the same person, topic, and general scope" do
      person = create(:person)
      create(:topic_subscription, person: person, topic_subscription_type: trainings, interested_event: nil)

      dupe = build(:topic_subscription, person: person, topic_subscription_type: trainings, interested_event: nil)
      expect(dupe).not_to be_valid
      expect(dupe.errors[:base]).to include("already has an active subscription for this topic")
    end

    it "allows the same person to subscribe to different topics" do
      person = create(:person)
      create(:topic_subscription, person: person, topic_subscription_type: trainings)

      news = build(:topic_subscription, person: person, topic_subscription_type: create(:topic_subscription_type, :news))
      expect(news).to be_valid
    end

    it "allows a general and an event-specific subscription for the same topic" do
      person = create(:person)
      create(:topic_subscription, person: person, topic_subscription_type: trainings, interested_event: nil)

      specific = build(:topic_subscription, person: person, topic_subscription_type: trainings, interested_event: create(:event))
      expect(specific).to be_valid
    end

    it "allows re-subscribing after an unsubscribe" do
      person = create(:person)
      create(:topic_subscription, :unsubscribed, person: person, topic_subscription_type: trainings, interested_event: nil)

      fresh = build(:topic_subscription, person: person, topic_subscription_type: trainings, interested_event: nil)
      expect(fresh).to be_valid
    end

    it "rejects an edit that collides with another active subscription" do
      person = create(:person)
      news = create(:topic_subscription_type, :news)
      create(:topic_subscription, person: person, topic_subscription_type: trainings)
      other = create(:topic_subscription, person: person, topic_subscription_type: news)

      other.topic_subscription_type = trainings

      expect(other).not_to be_valid
      expect(other.errors[:base]).to include("already has an active subscription for this topic")
    end

    it "still allows saving an unrelated edit to an active subscription" do
      subscription = create(:topic_subscription)
      expect(subscription.update(note: "Called in")).to be(true)
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
    end

    it "resubscribe clears unsubscribed_at" do
      subscription = create(:topic_subscription, :unsubscribed)
      expect(subscription.resubscribe).to be(true)
      expect(subscription.reload).to be_active
    end

    it "refuses to resubscribe onto an existing active subscription" do
      person = create(:person)
      stale = create(:topic_subscription, :unsubscribed, person: person, topic_subscription_type: trainings)
      create(:topic_subscription, person: person, topic_subscription_type: trainings)

      expect(stale.resubscribe).to be(false)
      expect(stale.reload).not_to be_active
    end
  end

  describe "#topic_label" do
    it "is the type's name" do
      subscription = build(:topic_subscription, topic_subscription_type: trainings)
      expect(subscription.topic_label).to eq("Facilitator trainings")
    end
  end

  describe "event scope" do
    it "keeps the event for an event-selector topic" do
      event = create(:event)
      subscription = create(:topic_subscription, topic_subscription_type: trainings, interested_event: event)
      expect(subscription.interested_event).to eq(event)
    end

    it "drops the event for a topic with no event dimension" do
      news = create(:topic_subscription_type, :news)
      subscription = create(:topic_subscription, topic_subscription_type: news, interested_event: create(:event))
      expect(subscription.interested_event).to be_nil
    end
  end

  describe "#general?" do
    it "is true without an event and false with one" do
      expect(build(:topic_subscription, interested_event: nil)).to be_general
      expect(build(:topic_subscription, interested_event: create(:event))).not_to be_general
    end
  end

  describe "scopes" do
    it "filters by state and topic type" do
      active = create(:topic_subscription, topic_subscription_type: trainings, interested_event: nil)
      gone = create(:topic_subscription, :unsubscribed, person: create(:person), topic_subscription_type: trainings)
      news_type = create(:topic_subscription_type, :news)
      news = create(:topic_subscription, person: create(:person), topic_subscription_type: news_type)
      specific = create(:topic_subscription, person: create(:person), topic_subscription_type: trainings, interested_event: create(:event))

      expect(described_class.active).to include(active, specific, news)
      expect(described_class.active).not_to include(gone)
      expect(described_class.unsubscribed).to contain_exactly(gone)
      expect(described_class.for_topic_type(news_type)).to contain_exactly(news)
    end
  end
end
