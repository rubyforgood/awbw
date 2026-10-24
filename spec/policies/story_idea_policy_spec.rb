require "rails_helper"

RSpec.describe StoryIdeaPolicy, type: :policy do
  let(:person) { build_stubbed(:person) }
  let(:credited_user) { build_stubbed(:user, person: person) }

  def policy_for(record:, user:)
    described_class.new(record, user: user)
  end

  describe "#show?" do
    it "allows an admin" do
      idea = build_stubbed(:story_idea, created_by: build_stubbed(:user))
      expect(policy_for(record: idea, user: build_stubbed(:user, :admin))).to be_allowed_to(:show?)
    end

    it "allows the submitter" do
      submitter = build_stubbed(:user)
      idea = build_stubbed(:story_idea, created_by: submitter)
      expect(policy_for(record: idea, user: submitter)).to be_allowed_to(:show?)
    end

    it "allows the credited author" do
      idea = build_stubbed(:story_idea, created_by: build_stubbed(:user), author: person)
      expect(policy_for(record: idea, user: credited_user)).to be_allowed_to(:show?)
    end

    it "allows the credited co-author" do
      idea = build_stubbed(:story_idea, created_by: build_stubbed(:user), co_author: person)
      expect(policy_for(record: idea, user: credited_user)).to be_allowed_to(:show?)
    end

    it "denies anyone else" do
      idea = build_stubbed(:story_idea, created_by: build_stubbed(:user), author: build_stubbed(:person))
      expect(policy_for(record: idea, user: credited_user)).not_to be_allowed_to(:show?)
    end

    it "denies a guest" do
      idea = build_stubbed(:story_idea, created_by: build_stubbed(:user))
      expect(policy_for(record: idea, user: nil)).not_to be_allowed_to(:show?)
    end
  end
end
