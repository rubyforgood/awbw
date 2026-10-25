require "rails_helper"

RSpec.describe AddressPolicy, type: :policy do
  def policy_for(user:)
    described_class.new(Address, user: user)
  end

  describe "#enter_any_state?" do
    it "lets an admin type any state" do
      expect(policy_for(user: build_stubbed(:user, super_user: true))).to be_allowed_to(:enter_any_state?)
    end

    it "keeps a regular user on the dropdown" do
      expect(policy_for(user: build_stubbed(:user, super_user: false))).not_to be_allowed_to(:enter_any_state?)
    end
  end
end
