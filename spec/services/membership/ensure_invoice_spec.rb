require "rails_helper"

RSpec.describe Membership::EnsureInvoice do
  let(:subscription) { create(:membership) }

  describe "creating the first invoice" do
    it "starts on the date asked for and runs a year" do
      invoice = described_class.call(membership: subscription, covering: Date.new(2026, 10, 14))

      expect(invoice.start_date).to eq(Date.new(2026, 10, 14))
      expect(invoice.end_date).to eq(Date.new(2027, 10, 13))
    end

    it "charges the standard cost" do
      invoice = described_class.call(membership: subscription)
      expect(invoice.cost_cents).to eq(Membership::ANNUAL_COST_CENTS)
    end

    it "charges the subscription's own cost when it has one" do
      subscription.update!(cost_cents: 1_500)
      expect(described_class.call(membership: subscription).cost_cents).to eq(1_500)
    end

    it "charges nothing when told to, for a year covered by training" do
      invoice = described_class.call(membership: subscription, cost_cents: 0)
      expect(invoice.cost_cents).to eq(0)
    end

    it "honours a zero cost on the subscription" do
      subscription.update!(cost_cents: 0)
      expect(described_class.call(membership: subscription).cost_cents).to eq(0)
    end
  end

  describe "when a invoice already covers the date" do
    let!(:existing) do
      create(:membership_invoice,
        membership: subscription,
        start_date: Date.new(2026, 10, 14),
        end_date: Date.new(2027, 10, 13))
    end

    it "returns it rather than creating another" do
      expect {
        expect(described_class.call(membership: subscription, covering: Date.new(2027, 1, 1)))
          .to eq(existing)
      }.not_to change(MembershipInvoice, :count)
    end

    it "returns it on the invoice's final day" do
      expect(described_class.call(membership: subscription, covering: existing.end_date))
        .to eq(existing)
    end

    it "is idempotent when called twice for the same date" do
      expect {
        2.times { described_class.call(membership: subscription, covering: Date.new(2027, 1, 1)) }
      }.not_to change(MembershipInvoice, :count)
    end
  end

  describe "renewing" do
    let!(:previous) do
      create(:membership_invoice,
        membership: subscription,
        start_date: Date.new(2026, 10, 14),
        end_date: Date.new(2027, 10, 13))
    end

    it "starts the day after the previous invoice ends" do
      invoice = described_class.call(membership: subscription, covering: Date.new(2027, 10, 14))

      expect(invoice.start_date).to eq(Date.new(2027, 10, 14))
      expect(invoice.end_date).to eq(Date.new(2028, 10, 13))
    end

    it "creates a invoice twice running without overlapping" do
      first = described_class.call(membership: subscription, covering: Date.new(2027, 10, 14))
      second = described_class.call(membership: subscription, covering: first.end_date + 1.day)

      expect(second.start_date).to eq(first.end_date + 1.day)
      expect(subscription.membership_invoices.count).to eq(3)
    end
  end

  describe "after a lapse" do
    let!(:long_ago) do
      create(:membership_invoice,
        membership: subscription,
        start_date: Date.new(2020, 1, 1),
        end_date: Date.new(2020, 12, 31))
    end

    it "starts fresh instead of backfilling the missed years" do
      invoice = described_class.call(membership: subscription, covering: Date.new(2026, 5, 1))

      expect(invoice.start_date).to eq(Date.new(2026, 5, 1))
      expect(subscription.membership_invoices.count).to eq(2)
    end
  end

  describe "a cancelled subscription" do
    before { subscription.update!(cancelled_at: Time.current) }

    it "creates nothing" do
      expect {
        expect(described_class.call(membership: subscription)).to be_nil
      }.not_to change(MembershipInvoice, :count)
    end

    it "still returns a invoice that already covers the date" do
      existing = create(:membership_invoice, membership: subscription)

      expect(described_class.call(membership: subscription)).to eq(existing)
    end
  end
end
