require "rails_helper"

RSpec.describe TopicSubscriptionType, type: :model do
  describe "validations" do
    it "requires a name" do
      expect(build(:topic_subscription_type, name: nil)).not_to be_valid
    end

    it "requires a unique name (case-insensitive)" do
      create(:topic_subscription_type, name: "News")
      expect(build(:topic_subscription_type, name: "news")).not_to be_valid
    end
  end

  describe "key" do
    it "derives a stable slug from the name on create" do
      type = create(:topic_subscription_type, name: "Facilitator trainings")
      expect(type.key).to eq("facilitator_trainings")
    end

    it "keeps the key fixed when the name is edited" do
      type = create(:topic_subscription_type, name: "Facilitator trainings")
      type.update!(name: "TAC trainings")
      expect(type.reload.key).to eq("facilitator_trainings")
    end
  end

  describe "event_selector" do
    it "defaults to false" do
      expect(create(:topic_subscription_type).event_selector?).to be(false)
    end
  end

  describe ".interested_in_more" do
    it "returns the facilitator_trainings type" do
      type = create(:topic_subscription_type, :facilitator_trainings)
      expect(described_class.interested_in_more).to eq(type)
    end
  end

  describe "archiving" do
    it "archives and unarchives" do
      type = create(:topic_subscription_type)
      type.archive!
      expect(type.reload).to be_archived
      expect(described_class.active).not_to include(type)

      type.unarchive!
      expect(type.reload).not_to be_archived
      expect(described_class.active).to include(type)
    end
  end

  describe "destroy" do
    it "is blocked while subscriptions exist" do
      type = create(:topic_subscription_type)
      create(:topic_subscription, topic_subscription_type: type)

      expect(type.destroy).to be_falsey
      expect(type.errors[:base]).to be_present
    end
  end
end
