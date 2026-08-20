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
end
