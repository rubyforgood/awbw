require "rails_helper"

RSpec.describe UserPolicy, type: :policy do
  let(:user) { build_stubbed(:user) }

  def policy_for(record:, user:)
    described_class.new(record, user: user)
  end

  describe "#self?" do
    it "allows the user viewing their own account" do
      expect(policy_for(record: user, user: user)).to be_allowed_to(:self?)
    end

    it "denies an admin viewing someone else's account" do
      expect(policy_for(record: user, user: build_stubbed(:user, :admin))).not_to be_allowed_to(:self?)
    end

    it "denies a guest" do
      expect(policy_for(record: user, user: nil)).not_to be_allowed_to(:self?)
    end
  end
end
