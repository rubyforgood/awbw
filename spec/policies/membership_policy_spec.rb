require "rails_helper"

RSpec.describe MembershipPolicy, type: :policy do
  let(:owner) { create(:user, :with_person) }
  let(:admin) { create(:user, :admin) }
  let(:other) { create(:user, :with_person) }
  let(:membership) { create(:membership, person: owner.person) }

  def policy_for(user:, record: membership)
    described_class.new(record, user: user)
  end

  describe "#show?" do
    it "allows the member who owns the membership" do
      expect(policy_for(user: owner)).to be_allowed_to(:show?)
    end

    it "allows an admin" do
      expect(policy_for(user: admin)).to be_allowed_to(:show?)
    end

    it "denies another member" do
      expect(policy_for(user: other)).not_to be_allowed_to(:show?)
    end

    it "denies everyone while membership is disabled" do
      allow(Membership).to receive(:enabled?).and_return(false)

      expect(policy_for(user: owner)).not_to be_allowed_to(:show?)
      expect(policy_for(user: admin)).not_to be_allowed_to(:show?)
    end
  end

  describe "#set_up_subscription?" do
    it "allows the member who owns a live membership" do
      expect(policy_for(user: owner)).to be_allowed_to(:set_up_subscription?)
    end

    it "denies a cancelled membership" do
      cancelled = create(:membership, :autorenewal_cancelled, person: owner.person)

      expect(policy_for(user: owner, record: cancelled)).not_to be_allowed_to(:set_up_subscription?)
    end

    it "denies another member's membership" do
      expect(policy_for(user: other)).not_to be_allowed_to(:set_up_subscription?)
    end

    it "denies when there is no membership record" do
      expect(policy_for(user: owner, record: nil)).not_to be_allowed_to(:set_up_subscription?)
    end

    it "denies while membership is disabled" do
      allow(Membership).to receive(:enabled?).and_return(false)

      expect(policy_for(user: owner)).not_to be_allowed_to(:set_up_subscription?)
    end
  end

  describe "#manage_subscription?" do
    it "allows the member who owns the membership" do
      expect(policy_for(user: owner)).to be_allowed_to(:manage_subscription?)
    end

    it "denies a member looking at someone else's membership" do
      expect(policy_for(user: other, record: membership)).not_to be_allowed_to(:manage_subscription?)
    end

    it "denies when no membership record is given" do
      expect(policy_for(user: owner, record: :membership)).not_to be_allowed_to(:manage_subscription?)
    end

    it "denies an admin who does not own the membership" do
      expect(policy_for(user: admin, record: membership)).not_to be_allowed_to(:manage_subscription?)
    end

    it "denies while membership is disabled" do
      allow(Membership).to receive(:enabled?).and_return(false)

      expect(policy_for(user: owner)).not_to be_allowed_to(:manage_subscription?)
    end
  end
end
