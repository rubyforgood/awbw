require "rails_helper"

RSpec.describe TopicSubscriptionDecorator do
  let(:trainings) { create(:topic_subscription_type, :facilitator_trainings) }
  let(:news) { create(:topic_subscription_type, :news) }

  describe "#event_label" do
    it "is the event title for an event-specific subscription" do
      event = create(:event, title: "Spring Training")
      subscription = create(:topic_subscription, topic_subscription_type: trainings, interested_event: event)
      expect(subscription.decorate.event_label).to eq("Spring Training")
    end

    it "is 'Any — <topic>' for a broad subscription to an event-oriented topic" do
      subscription = create(:topic_subscription, topic_subscription_type: trainings, interested_event: nil)
      expect(subscription.decorate.event_label).to eq("Any — facilitator trainings")
    end

    it "is 'N/A' for a topic with no event dimension" do
      subscription = create(:topic_subscription, topic_subscription_type: news)
      expect(subscription.decorate.event_label).to eq("N/A")
    end
  end

  describe "#general_event_scope?" do
    it "is true only for a broad subscription to an event-oriented topic" do
      broad = create(:topic_subscription, topic_subscription_type: trainings, interested_event: nil)
      non_event = create(:topic_subscription, topic_subscription_type: news)
      specific = create(:topic_subscription, topic_subscription_type: trainings, interested_event: create(:event))

      expect(broad.decorate).to be_general_event_scope
      expect(non_event.decorate).not_to be_general_event_scope
      expect(specific.decorate).not_to be_general_event_scope
    end
  end
end
