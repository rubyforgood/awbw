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

    it "rejects end_date before start_date" do
      subscription = build(:membership, start_date: Date.current + 1.month, end_date: Date.current)
      expect(subscription).not_to be_valid
      expect(subscription.errors[:end_date]).to be_present
    end

    it "rejects overlapping dates with an existing membership for the same person" do
      person = create(:person)
      create(:membership, :autorenewal_cancelled, person: person,
        start_date: Date.current - 1.month, end_date: Date.current + 1.month)

      overlap = build(:membership, person: person, start_date: Date.current, end_date: Date.current + 2.months)
      expect(overlap).not_to be_valid
      expect(overlap.errors[:base].join).to match(/overlaps/)
    end

    it "allows a new membership with non-overlapping dates when the previous is cancelled" do
      person = create(:person)
      create(:membership, :autorenewal_cancelled, person: person,
        start_date: Date.current - 2.months, end_date: Date.current - 1.month)

      expect(build(:membership, person: person, start_date: Date.current, end_date: Date.current + 1.month)).to be_valid
    end

    it "rejects a second uncancelled membership for the same person" do
      person = create(:person)
      create(:membership, person: person)

      second = build(:membership, person: person)
      expect(second).not_to be_valid
      expect(second.errors[:base].join).to match(/already has a membership/)
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

  describe "scopes" do
    it "autorenewal_not_cancelled excludes cancelled memberships" do
      open_subscription = create(:membership)
      create(:membership, :autorenewal_cancelled)

      expect(described_class.autorenewal_not_cancelled).to contain_exactly(open_subscription)
    end
  end

  describe "#active?" do
    it "is true when end_date is in the future" do
      expect(create(:membership, end_date: Date.current + 1.month)).to be_active
    end

    it "is false when end_date is in the past" do
      expect(create(:membership, start_date: Date.current - 2.months, end_date: Date.current - 1.month)).not_to be_active
    end

    it "is false when end_date is nil" do
      membership = create(:membership).tap { |m| m.update!(end_date: nil) }

      expect(membership).not_to be_active
    end
  end

  describe "#upcoming?" do
    it "is true when the start date is in the future" do
      membership = create(:membership, start_date: Date.current + 1.month, end_date: Date.current + 1.year)

      expect(membership).to be_upcoming
    end

    it "is true when an invoice starts in the future and the membership has no dates yet" do
      membership = create(:membership).tap { |m| m.update!(start_date: nil, end_date: nil) }
      create(:membership_invoice, membership: membership,
        start_date: Date.current + 1.month, end_date: Date.current + 1.year - 1.day)

      expect(membership.reload).to be_upcoming
    end

    it "is false while the membership is active, even with a future invoice" do
      membership = create(:membership)
      create(:membership_invoice, membership: membership,
        start_date: Date.current + 1.year, end_date: Date.current + 2.years - 1.day)

      expect(membership.reload).not_to be_upcoming
    end
  end

  describe "associations" do
    it "is reachable from the person, along with their invoices" do
      subscription = create(:membership)
      invoice = create(:membership_invoice, membership: subscription)

      expect(subscription.person.memberships).to contain_exactly(subscription)
      expect(subscription.person.membership_invoices).to contain_exactly(invoice)
    end
  end

  describe "#invoices_due" do
    let(:membership) { create(:membership) }

    it "returns unpaid invoices, newest first" do
      older = create(:membership_invoice, membership: membership, cost_cents: 2_500,
        start_date: Date.current - 2.years, end_date: Date.current - 1.year - 1.day)
      newer = create(:membership_invoice, membership: membership, cost_cents: 2_500,
        start_date: Date.current - 1.month, end_date: Date.current + 11.months)

      expect(membership.invoices_due.to_a).to eq([ newer, older ])
    end

    it "excludes paid and comped invoices" do
      create(:membership_invoice, :comped, membership: membership,
        start_date: Date.current - 2.years, end_date: Date.current - 1.year - 1.day)
      paid = create(:membership_invoice, membership: membership)
      create(:allocation, source: create(:payment, amount_cents: paid.cost_cents),
        allocatable: paid, amount: paid.cost_cents)

      expect(membership.invoices_due).to be_empty
    end
  end

  describe "#next_billing_cents" do
    let(:membership) { create(:membership) }

    it "uses the earliest future invoice's price over the membership's own cost" do
      membership.update!(cost_cents: 1_500)
      create(:membership_invoice, membership: membership, cost_cents: 2_500,
        start_date: Date.current + 1.year, end_date: Date.current + 2.years - 1.day)

      expect(membership.next_billing_cents).to eq(2_500)
    end

    it "falls back to the membership's locked cost" do
      membership.update!(cost_cents: 1_500)

      expect(membership.next_billing_cents).to eq(1_500)
    end

    it "falls back to the standard cost" do
      expect(membership.next_billing_cents).to eq(Membership.annual_cost_cents)
    end

    it "is zero when the next year is comped" do
      create(:membership_invoice, :comped, membership: membership,
        start_date: Date.current + 1.year, end_date: Date.current + 2.years - 1.day)

      expect(membership.next_billing_cents).to eq(0)
    end
  end

  describe "#next_billing_start_date" do
    let(:membership) { create(:membership) }

    it "is the day after paid coverage ends" do
      membership = create(:membership, start_date: nil, end_date: nil)
      invoice = create(:membership_invoice, membership: membership, cost_cents: 2_500,
        start_date: Date.current - 1.month, end_date: Date.current + 11.months)
      create(:allocation, source: create(:payment, amount_cents: 2_500),
        allocatable: invoice, amount: 2_500)

      expect(membership.reload.next_billing_start_date).to eq(invoice.end_date + 1.day)
    end

    it "is the next billed year when nothing covers today" do
      upcoming = create(:membership_invoice, membership: membership,
        start_date: Date.current + 1.month, end_date: Date.current + 13.months)

      expect(membership.next_billing_start_date).to eq(upcoming.start_date)
    end

    it "is nil when the membership has lapsed with nothing ahead" do
      create(:membership_invoice, membership: membership, cost_cents: 2_500,
        start_date: Date.current - 2.years, end_date: Date.current - 1.year - 1.day)

      expect(membership.next_billing_start_date).to be_nil
    end

    it "is the day after coverage ends when a later year leaves a gap" do
      membership = create(:membership, start_date: nil, end_date: nil)
      covered = create(:membership_invoice, membership: membership, cost_cents: 2_500,
        start_date: Date.current - 1.month, end_date: Date.current + 11.months)
      create(:allocation, source: create(:payment, amount_cents: 2_500),
        allocatable: covered, amount: 2_500)
      create(:membership_invoice, membership: membership,
        start_date: covered.end_date + 1.year, end_date: covered.end_date + 2.years)

      expect(membership.reload.next_billing_start_date).to eq(covered.end_date + 1.day)
    end

    it "skips a comped upcoming year" do
      covered = create(:membership_invoice, membership: membership, cost_cents: 2_500,
        start_date: Date.current - 1.month, end_date: Date.current + 11.months)
      create(:allocation, source: create(:payment, amount_cents: 2_500),
        allocatable: covered, amount: 2_500)
      create(:membership_invoice, :comped, membership: membership,
        start_date: covered.end_date + 1.day, end_date: covered.end_date + 1.year)

      expect(membership.next_billing_invoice).to be_nil
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

  describe "#stripe_active? and #stripe_past_due?" do
    def stripe_subscription_status(membership, status)
      customer = Pay::Customer.create!(owner: membership.person, processor: "stripe",
        processor_id: "cus_#{membership.id}", default: true)
      Pay::Stripe::Subscription.create!(customer: customer, name: "default",
        processor_id: "sub_#{membership.id}", processor_plan: "membership",
        status: status, quantity: 1, metadata: { "membership_id" => membership.id })
    end

    it "asks Pay whether this membership's subscription is active" do
      membership = create(:membership)
      stripe_subscription_status(membership, "active")

      expect(membership.stripe_active?).to be(true)
      expect(membership.stripe_past_due?).to be(false)
    end

    it "reports a past-due subscription as past due, not active" do
      membership = create(:membership)
      stripe_subscription_status(membership, "past_due")

      expect(membership.stripe_active?).to be(false)
      expect(membership.stripe_past_due?).to be(true)
    end

    it "is nil without a subscription" do
      membership = create(:membership)

      expect(membership.stripe_active?).to be_nil
      expect(membership.stripe_past_due?).to be_nil
    end
  end

  describe "#sync_dates_from_invoice" do
    it "sets start_date and end_date from a paid invoice" do
      membership = create(:membership).tap { |m| m.update!(end_date: nil) }
      invoice = build(:membership_invoice, membership: membership,
        start_date: Date.current - 1.month, end_date: Date.current + 11.months, cost_cents: 0)

      invoice.save!
      membership.reload

      expect(membership.start_date).to eq(Date.current - 1.month)
      expect(membership.end_date).to eq(Date.current + 11.months)
    end

    it "never decreases end_date" do
      membership = create(:membership, end_date: Date.current + 2.years)
      invoice = build(:membership_invoice, membership: membership,
        start_date: Date.current - 1.month, end_date: Date.current + 11.months, cost_cents: 0)

      invoice.save!
      membership.reload

      expect(membership.end_date).to eq(Date.current + 2.years)
    end

    it "does not sync dates for unpaid invoices" do
      membership = create(:membership)
      original_start = membership.start_date
      original_end = membership.end_date
      invoice = build(:membership_invoice, membership: membership,
        start_date: Date.current - 1.month, end_date: Date.current + 11.months, cost_cents: 1_500)

      invoice.save!
      membership.reload

      expect(membership.start_date).to eq(original_start)
      expect(membership.end_date).to eq(original_end)
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

  describe "autorenewal-cancelling a membership" do
    it "cancels the linked Stripe subscription immediately so the portal can't re-enable autopay" do
      membership = create(:membership)
      subscription = instance_double("Pay::Stripe::Subscription", active?: true)
      allow(membership).to receive(:stripe_subscription).and_return(subscription)

      expect(subscription).to receive(:cancel_now!)
      membership.update!(autorenewal_cancelled_at: Time.current)
    end

    it "leaves a membership with no Stripe subscription untouched" do
      membership = create(:membership)

      expect { membership.update!(autorenewal_cancelled_at: Time.current) }.not_to raise_error
      expect(membership.reload).to be_autorenewal_cancelled
    end

    it "does not cancel anything when resuming (clearing autorenewal_cancelled_at)" do
      membership = create(:membership, :autorenewal_cancelled)
      allow(membership).to receive(:stripe_subscription)

      membership.update!(autorenewal_cancelled_at: nil)

      expect(membership).not_to have_received(:stripe_subscription)
    end

    it "still saves the local cancel when Stripe errors" do
      membership = create(:membership)
      subscription = instance_double("Pay::Stripe::Subscription", active?: true)
      allow(membership).to receive(:stripe_subscription).and_return(subscription)
      allow(subscription).to receive(:cancel_now!).and_raise(Pay::Stripe::Error.new("boom"))
      allow(Rails.logger).to receive(:warn)

      expect { membership.update!(autorenewal_cancelled_at: Time.current) }.not_to raise_error
      expect(membership.reload).to be_autorenewal_cancelled
      expect(Rails.logger).to have_received(:warn).with(/Stripe/i)
    end
  end
end
