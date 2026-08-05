require "rails_helper"

RSpec.describe DuesSubscriptionDecorator, type: :decorator do
  let(:standard_rate) { MoneyFormatter.dollars_from_cents(Dues::ANNUAL_COST_CENTS) }

  describe "#rate_label" do
    it "names the standard rate when there is no override" do
      expect(create(:dues_subscription, rate_cents: nil).decorate.rate_label)
        .to eq("Standard (#{standard_rate})")
    end

    it "names the locked rate when there is one" do
      expect(create(:dues_subscription, rate_cents: 1_500).decorate.rate_label).to eq("Locked at $15")
    end

    it "treats a zero rate as locked, not standard" do
      expect(create(:dues_subscription, rate_cents: 0).decorate.rate_label).to eq("Locked at $0")
    end
  end

  describe "#status_label" do
    it "reads Active while uncancelled" do
      expect(create(:dues_subscription).decorate.status_label).to eq("Active")
    end

    it "reads the cancellation date once cancelled" do
      subscription = create(:dues_subscription, cancelled_at: Time.zone.parse("2026-08-03 12:00"))

      expect(subscription.decorate.status_label).to eq("Cancelled Aug 3, 2026")
    end
  end
end
