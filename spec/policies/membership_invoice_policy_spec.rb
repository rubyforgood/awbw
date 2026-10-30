require "rails_helper"

RSpec.describe MembershipInvoicePolicy, type: :policy do
  let(:owner) { create(:user, :with_person) }
  let(:admin) { create(:user, :admin) }
  let(:other) { create(:user, :with_person) }
  let(:membership) { create(:membership, person: owner.person) }
  let(:invoice) { create(:membership_invoice, membership: membership) }

  def policy_for(user:, record: invoice)
    described_class.new(record, user: user)
  end

  describe "#manage?" do
    it "allows an admin while memberships are enabled" do
      expect(policy_for(user: admin)).to be_allowed_to(:manage?)
    end

    it "denies an owner and a disabled membership" do
      expect(policy_for(user: owner)).not_to be_allowed_to(:manage?)

      allow(Membership).to receive(:enabled?).and_return(false)
      expect(policy_for(user: admin)).not_to be_allowed_to(:manage?)
    end
  end

  describe "#show?" do
    it "allows an admin and the owner" do
      expect(policy_for(user: admin)).to be_allowed_to(:show?)
      expect(policy_for(user: owner)).to be_allowed_to(:show?)
    end

    it "denies another member and a disabled membership" do
      expect(policy_for(user: other)).not_to be_allowed_to(:show?)

      allow(Membership).to receive(:enabled?).and_return(false)
      expect(policy_for(user: owner)).not_to be_allowed_to(:show?)
    end
  end

  describe "#new? / #create?" do
    it "allows an admin on an unlocked membership" do
      expect(policy_for(user: admin)).to be_allowed_to(:new?)
      expect(policy_for(user: admin)).to be_allowed_to(:create?)
    end

    it "denies a locked membership, an owner, and a disabled membership" do
      membership.update_column(:locked_at, Time.current)
      invoice.reload
      expect(policy_for(user: admin)).not_to be_allowed_to(:new?)

      expect(policy_for(user: owner)).not_to be_allowed_to(:new?)

      allow(Membership).to receive(:enabled?).and_return(false)
      expect(policy_for(user: admin)).not_to be_allowed_to(:new?)
    end
  end

  describe "#edit? / #update?" do
    it "allows an admin on an unlocked invoice with no payment in progress" do
      expect(policy_for(user: admin)).to be_allowed_to(:edit?)
      expect(policy_for(user: admin)).to be_allowed_to(:update?)
    end

    it "denies a locked membership and a payment in progress" do
      membership.update_column(:locked_at, Time.current)
      invoice.reload
      expect(policy_for(user: admin)).not_to be_allowed_to(:edit?)

      membership.update_column(:locked_at, nil)
      invoice.reload
      invoice.update_column(:payment_in_progress_at, Time.current)
      expect(policy_for(user: admin)).not_to be_allowed_to(:edit?)
    end

    it "denies edit while an autopay attempt is pending" do
      invoice.charge_attempts.create!(
        attempt_number: 1,
        status: "pending",
        amount_cents: 100,
        attempted_at: 5.minutes.ago
      )

      expect(policy_for(user: admin)).not_to be_allowed_to(:edit?)
    end

    it "denies an owner" do
      expect(policy_for(user: owner)).not_to be_allowed_to(:edit?)
    end
  end

  describe "#destroy?" do
    it "allows an admin on an unlocked membership" do
      expect(policy_for(user: admin)).to be_allowed_to(:destroy?)
    end

    it "denies a locked membership and an owner" do
      membership.update_column(:locked_at, Time.current)
      invoice.reload
      expect(policy_for(user: admin)).not_to be_allowed_to(:destroy?)

      expect(policy_for(user: owner)).not_to be_allowed_to(:destroy?)
    end
  end

  describe "#show_public?" do
    it "allows while memberships are enabled and denies when disabled" do
      expect(policy_for(user: owner)).to be_allowed_to(:show_public?)

      allow(Membership).to receive(:enabled?).and_return(false)
      expect(policy_for(user: owner)).not_to be_allowed_to(:show_public?)
    end
  end

  describe "#pay?" do
    it "allows the member who owns the invoice and denies everyone else" do
      expect(policy_for(user: owner)).to be_allowed_to(:pay?)
      expect(policy_for(user: other)).not_to be_allowed_to(:pay?)
      expect(policy_for(user: admin)).not_to be_allowed_to(:pay?)
    end

    it "denies when membership is disabled" do
      allow(Membership).to receive(:enabled?).and_return(false)

      expect(policy_for(user: owner)).not_to be_allowed_to(:pay?)
    end
  end
end
