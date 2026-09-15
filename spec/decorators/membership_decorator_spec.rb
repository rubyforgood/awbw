require "rails_helper"

RSpec.describe MembershipDecorator, type: :decorator do
  let(:standard_cost) { MoneyFormatter.dollars_from_cents(Membership::ANNUAL_COST_CENTS) }

  describe "#cost_label" do
    it "names the standard cost when there is no override" do
      expect(create(:membership, cost_cents: nil).decorate.cost_label)
        .to eq("Standard (#{standard_cost})")
    end

    it "names the locked cost when there is one" do
      expect(create(:membership, cost_cents: 1_500).decorate.cost_label).to eq("Locked at $15")
    end

    it "treats a zero cost as locked, not standard" do
      expect(create(:membership, cost_cents: 0).decorate.cost_label).to eq("Locked at $0")
    end
  end

  describe "#status_label" do
    it "reads Active while uncancelled" do
      expect(create(:membership).decorate.status_label).to eq("Active")
    end

    it "reads the cancellation date once cancelled" do
      subscription = create(:membership, cancelled_at: Time.zone.parse("2026-08-03 12:00"))

      expect(subscription.decorate.status_label).to eq("Cancelled Aug 3, 2026")
    end
  end

  describe "#period_label" do
    it "spans the earliest invoice start to the latest invoice end" do
      membership = create(:membership)
      create(:membership_invoice, membership: membership, start_date: Date.new(2025, 1, 15), end_date: Date.new(2026, 1, 15))
      create(:membership_invoice, membership: membership, start_date: Date.new(2026, 1, 16), end_date: Date.new(2027, 1, 15))

      expect(membership.reload.decorate.period_label).to eq("Jan 15, 2025 – Jan 15, 2027")
    end

    it "is nil when there are no invoices" do
      expect(create(:membership).decorate.period_label).to be_nil
    end
  end
end
