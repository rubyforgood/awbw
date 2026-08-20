require "rails_helper"

RSpec.describe Membership, type: :model do
  describe "validations" do
    it "allows a nil cost_cents, meaning the standard cost" do
      expect(build(:membership, cost_cents: nil)).to be_valid
    end

    it "allows a zero cost_cents, meaning a comped member" do
      expect(build(:membership, cost_cents: 0)).to be_valid
    end

    it "rejects a negative cost_cents" do
      subscription = build(:membership, cost_cents: -1)
      expect(subscription).not_to be_valid
      expect(subscription.errors[:cost_cents]).to be_present
    end

    it "rejects a second uncancelled subscription for the same person" do
      person = create(:person)
      create(:membership, person: person)

      second = build(:membership, person: person)
      expect(second).not_to be_valid
      expect(second.errors[:base].join).to match(/already has a membership/)
    end

    it "allows a new subscription once the previous one is cancelled" do
      person = create(:person)
      create(:membership, :cancelled, person: person)

      expect(build(:membership, person: person)).to be_valid
    end

    it "allows two people to each have an uncancelled subscription" do
      create(:membership)
      expect(build(:membership)).to be_valid
    end

    it "does not treat a persisted subscription as its own duplicate" do
      subscription = create(:membership)
      subscription.cost_cents = 1_500
      expect(subscription).to be_valid
    end
  end

  describe "#cancelled?" do
    it "is false while cancelled_at is blank" do
      expect(build(:membership)).not_to be_cancelled
    end

    it "is true once cancelled_at is stamped" do
      expect(build(:membership, :cancelled)).to be_cancelled
    end
  end

  describe "scopes" do
    let!(:open_subscription) { create(:membership) }
    let!(:cancelled_subscription) { create(:membership, :cancelled) }

    it "separates cancelled from uncancelled" do
      expect(described_class.not_cancelled).to contain_exactly(open_subscription)
      expect(described_class.cancelled).to contain_exactly(cancelled_subscription)
    end
  end

  describe "associations" do
    it "destroys its invoices with it" do
      subscription = create(:membership)
      create(:membership_invoice, membership: subscription)

      expect { subscription.destroy }.to change(MembershipInvoice, :count).by(-1)
    end

    it "is reachable from the person, along with their invoices" do
      subscription = create(:membership)
      invoice = create(:membership_invoice, membership: subscription)

      expect(subscription.person.memberships).to contain_exactly(subscription)
      expect(subscription.person.membership_invoices).to contain_exactly(invoice)
    end
  end
end
