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

  describe "#auto_renewal_label" do
    it "reads enabled when not autorenewal_cancelled" do
      expect(create(:membership).decorate.auto_renewal_label).to eq("enabled")
    end

    it "reads the cancelled date once autorenewal_cancelled" do
      subscription = create(:membership, autorenewal_cancelled_at: Time.zone.parse("2026-08-03 12:00"))

      expect(subscription.decorate.auto_renewal_label).to eq("cancelled on Aug 3, 2026")
    end
  end

  describe "#period_label" do
    it "shows the date range when current and not autorenewal_cancelled" do
      membership = create(:membership, start_date: Date.new(2025, 1, 15), end_date: Date.new(2027, 1, 15))

      expect(membership.reload.decorate.period_label).to eq("Jan 15, 2025 – present")
    end

    it "is nil when there are no dates" do
      membership = build(:membership, start_date: nil, end_date: nil)

      expect(membership.decorate.period_label).to be_nil
    end

    it "shows the fixed end date when cancelled and expired" do
      membership = create(:membership, start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31), autorenewal_cancelled_at: Time.zone.parse("2026-08-03 12:00"))

      expect(membership.reload.decorate.period_label).to eq("Jan 1, 2025 – Dec 31, 2025")
    end

    it "shows present when cancelled but still current" do
      membership = create(:membership, start_date: Date.new(2025, 1, 1), end_date: Date.new(2027, 1, 1), autorenewal_cancelled_at: Time.zone.parse("2026-08-03 12:00"))

      expect(membership.reload.decorate.period_label).to eq("Jan 1, 2025 – present")
    end
  end
end
