require "rails_helper"

RSpec.describe MembershipInvoicePolicy, type: :policy do
  let(:owner) { create(:user, :with_person) }
  let(:admin) { create(:user, :admin) }
  let(:other) { create(:user, :with_person) }
  let(:invoice) { create(:membership_invoice, membership: create(:membership, person: owner.person)) }

  def policy_for(user:, record: invoice)
    described_class.new(record, user: user)
  end

  describe "#checkout?" do
    it "allows the member who owns the invoice" do
      expect(policy_for(user: owner)).to be_allowed_to(:checkout?)
    end

    it "denies another member's invoice" do
      expect(policy_for(user: other)).not_to be_allowed_to(:checkout?)
    end

    it "denies an admin who does not own the invoice" do
      expect(policy_for(user: admin)).not_to be_allowed_to(:checkout?)
    end

    it "denies when there is no invoice record" do
      expect(policy_for(user: owner, record: nil)).not_to be_allowed_to(:checkout?)
    end

    it "denies while membership is disabled" do
      allow(Membership).to receive(:enabled?).and_return(false)

      expect(policy_for(user: owner)).not_to be_allowed_to(:checkout?)
    end
  end
end
