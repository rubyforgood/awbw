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
    it "denies the member who owns the membership" do
      expect(policy_for(user: owner)).not_to be_allowed_to(:show?)
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

  describe "#edit? / #update?" do
    it "allows an admin on an unlocked membership" do
      expect(policy_for(user: admin)).to be_allowed_to(:edit?)
      expect(policy_for(user: admin)).to be_allowed_to(:update?)
    end

    it "denies an admin on a locked membership" do
      membership.update_column(:locked_at, Time.current)

      expect(policy_for(user: admin)).not_to be_allowed_to(:edit?)
      expect(policy_for(user: admin)).not_to be_allowed_to(:update?)
    end

    it "denies an owner and another member" do
      expect(policy_for(user: owner)).not_to be_allowed_to(:edit?)
      expect(policy_for(user: other)).not_to be_allowed_to(:edit?)
    end
  end

  describe "#destroy?" do
    it "allows an admin, including a locked membership (the service enforces the guard)" do
      expect(policy_for(user: admin)).to be_allowed_to(:destroy?)

      membership.update_column(:locked_at, Time.current)
      expect(policy_for(user: admin)).to be_allowed_to(:destroy?)
    end

    it "denies owners, other members, unpersisted records, and disabled memberships" do
      expect(policy_for(user: owner)).not_to be_allowed_to(:destroy?)
      expect(policy_for(user: other)).not_to be_allowed_to(:destroy?)
      expect(policy_for(user: admin, record: build(:membership))).not_to be_allowed_to(:destroy?)

      allow(Membership).to receive(:enabled?).and_return(false)
      expect(policy_for(user: admin)).not_to be_allowed_to(:destroy?)
    end
  end

  describe "#unlock?" do
    it "allows an admin, including a locked membership" do
      expect(policy_for(user: admin)).to be_allowed_to(:unlock?)

      membership.update_column(:locked_at, Time.current)
      expect(policy_for(user: admin)).to be_allowed_to(:unlock?)
    end

    it "denies owners, other members, unpersisted records, and disabled memberships" do
      expect(policy_for(user: owner)).not_to be_allowed_to(:unlock?)
      expect(policy_for(user: other)).not_to be_allowed_to(:unlock?)
      expect(policy_for(user: admin, record: build(:membership))).not_to be_allowed_to(:unlock?)

      allow(Membership).to receive(:enabled?).and_return(false)
      expect(policy_for(user: admin)).not_to be_allowed_to(:unlock?)
    end
  end

  describe "#remove_next_year?" do
    it "allows an admin on an unlocked membership" do
      expect(policy_for(user: admin)).to be_allowed_to(:remove_next_year?)
    end

    it "denies a locked membership, an owner, and a disabled membership" do
      membership.update_column(:locked_at, Time.current)
      expect(policy_for(user: admin)).not_to be_allowed_to(:remove_next_year?)

      expect(policy_for(user: owner)).not_to be_allowed_to(:remove_next_year?)

      allow(Membership).to receive(:enabled?).and_return(false)
      expect(policy_for(user: admin)).not_to be_allowed_to(:remove_next_year?)
    end
  end

  describe "#enable_autopay?" do
    it "allows the owner of an unlocked membership" do
      expect(policy_for(user: owner)).to be_allowed_to(:enable_autopay?)
    end

    it "denies an admin, another member, a locked membership, and a disabled membership" do
      expect(policy_for(user: admin)).not_to be_allowed_to(:enable_autopay?)
      expect(policy_for(user: other)).not_to be_allowed_to(:enable_autopay?)

      membership.update_column(:locked_at, Time.current)
      expect(policy_for(user: owner)).not_to be_allowed_to(:enable_autopay?)

      allow(Membership).to receive(:enabled?).and_return(false)
      expect(policy_for(user: owner)).not_to be_allowed_to(:enable_autopay?)
    end
  end

  describe "#disable_autopay?" do
    it "allows the owner and an admin" do
      expect(policy_for(user: owner)).to be_allowed_to(:disable_autopay?)
      expect(policy_for(user: admin)).to be_allowed_to(:disable_autopay?)
    end

    it "denies another member and a disabled membership" do
      expect(policy_for(user: other)).not_to be_allowed_to(:disable_autopay?)

      allow(Membership).to receive(:enabled?).and_return(false)
      expect(policy_for(user: owner)).not_to be_allowed_to(:disable_autopay?)
    end
  end

  describe "#manage_membership?" do
    it "allows the owner" do
      expect(policy_for(user: owner)).to be_allowed_to(:manage_membership?)
    end

    it "denies another member, an admin who does not own it, a missing record, and disabled memberships" do
      expect(policy_for(user: other)).not_to be_allowed_to(:manage_membership?)
      expect(policy_for(user: admin)).not_to be_allowed_to(:manage_membership?)
      expect(policy_for(user: owner, record: :membership)).not_to be_allowed_to(:manage_membership?)

      allow(Membership).to receive(:enabled?).and_return(false)
      expect(policy_for(user: owner)).not_to be_allowed_to(:manage_membership?)
    end
  end
end
