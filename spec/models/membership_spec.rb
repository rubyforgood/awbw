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

  describe "#stripe_subscription" do
    it "finds the Pay::Subscription carrying this membership's id in its metadata" do
      membership = create(:membership)
      customer = Pay::Customer.create!(owner: membership.person, processor: "stripe",
        processor_id: "cus_test", default: true)
      subscription = Pay::Subscription.create!(customer: customer, name: "default",
        processor_id: "sub_test", processor_plan: "membership", status: "active", quantity: 1,
        metadata: { "membership_id" => membership.id })
      Pay::Subscription.create!(customer: customer, name: "default",
        processor_id: "sub_other", processor_plan: "membership", status: "active", quantity: 1,
        metadata: { "membership_id" => create(:membership).id })

      expect(membership.stripe_subscription).to eq(subscription)
    end

    it "is nil for a membership with no subscription" do
      expect(create(:membership).stripe_subscription).to be_nil
    end

    it "does not create a Pay customer just by looking" do
      membership = create(:membership)

      expect { membership.stripe_subscription }.not_to change { membership.person.pay_customers.count }
    end
  end

  describe "#good_through" do
    it "returns the active membership invoice's end date" do
      membership = create(:membership)
      invoice = create(:membership_invoice, membership: membership,
        start_date: Date.current - 1.month, end_date: Date.current + 11.months)

      expect(membership.good_through).to eq(invoice.end_date)
    end

    it "is nil when no invoice covers today" do
      membership = create(:membership)
      create(:membership_invoice, membership: membership,
        start_date: Date.current + 1.month, end_date: Date.current + 13.months)

      expect(membership.good_through).to be_nil
    end
  end

  describe "deleting a membership" do
    it "is deletable when no invoice has anything allocated" do
      membership = create(:membership)
      create(:membership_invoice, :comped, membership: membership)

      expect(membership).to be_deletable
      expect(membership.deletion_blocked_reason).to be_nil
    end

    it "is not deletable when an invoice has an allocation" do
      membership = create(:membership)
      invoice = create(:membership_invoice, membership: membership)
      create(:allocation, source: create(:payment, amount_cents: 100), allocatable: invoice, amount: 100)

      expect(membership.reload).not_to be_deletable
      expect(membership.deletion_blocked_reason).to match(/payments or credits/)
    end

    it "cascades its invoices, even ones their own guard would protect" do
      membership = create(:membership)
      create(:membership_invoice, membership: membership)

      expect { membership.destroy }.to change(MembershipInvoice, :count).by(-1)
    end

    it "cancels the linked Stripe subscription so billing stops" do
      membership = create(:membership)
      subscription = instance_double("Pay::Stripe::Subscription", active?: true)
      allow(membership).to receive(:stripe_subscription).and_return(subscription)

      expect(subscription).to receive(:cancel_now!)
      membership.destroy
    end

    it "refuses to destroy when an invoice has an allocation" do
      membership = create(:membership)
      invoice = create(:membership_invoice, membership: membership)
      create(:allocation, source: create(:payment, amount_cents: 100), allocatable: invoice, amount: 100)

      expect { membership.destroy }.not_to change(Membership, :count)
      expect(membership.errors[:base].join).to match(/Cannot delete/)
    end

    it "still cascade-destroys when its person is deleted" do
      person = create(:person)
      membership = create(:membership, person: person)
      invoice = create(:membership_invoice, membership: membership)
      create(:allocation, source: create(:payment, amount_cents: 100), allocatable: invoice, amount: 100)

      expect { person.destroy }.to change(Person, :count).by(-1)
      expect(Membership.exists?(membership.id)).to be false
    end
  end

  describe "cancelling a membership" do
    it "cancels the linked Stripe subscription immediately so the portal can't re-enable autopay" do
      membership = create(:membership)
      subscription = instance_double("Pay::Stripe::Subscription", active?: true)
      allow(membership).to receive(:stripe_subscription).and_return(subscription)

      expect(subscription).to receive(:cancel_now!)
      membership.update!(cancelled_at: Time.current)
    end

    it "leaves a membership with no Stripe subscription untouched" do
      membership = create(:membership)

      expect { membership.update!(cancelled_at: Time.current) }.not_to raise_error
      expect(membership.reload).to be_cancelled
    end

    it "does not cancel anything when resuming (clearing cancelled_at)" do
      membership = create(:membership, :cancelled)
      allow(membership).to receive(:stripe_subscription)

      membership.update!(cancelled_at: nil)

      expect(membership).not_to have_received(:stripe_subscription)
    end

    it "still saves the local cancel when Stripe errors" do
      membership = create(:membership)
      subscription = instance_double("Pay::Stripe::Subscription", active?: true)
      allow(membership).to receive(:stripe_subscription).and_return(subscription)
      allow(subscription).to receive(:cancel_now!).and_raise(Pay::Stripe::Error.new("boom"))
      allow(Rails.logger).to receive(:warn)

      expect { membership.update!(cancelled_at: Time.current) }.not_to raise_error
      expect(membership.reload).to be_cancelled
      expect(Rails.logger).to have_received(:warn).with(/Stripe/i)
    end
  end
end
