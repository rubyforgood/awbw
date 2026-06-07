require "rails_helper"

RSpec.describe GrantDecorator, type: :decorator do
  describe "money formatting" do
    let(:grant) { create(:grant, amount_cents: 100_000).decorate }

    it "formats the donation amount" do
      expect(grant.amount).to eq("$1,000.00")
    end

    it "formats the remaining balance" do
      create(:scholarship, grant: grant.object, amount_cents: 40_000)
      expect(grant.remaining).to eq("$600.00")
    end
  end

  describe "#fully_allocated?" do
    let(:grant) { create(:grant, amount_cents: 50_000) }

    it "is true once scholarships consume the full amount" do
      create(:scholarship, grant:, amount_cents: 50_000)
      expect(grant.decorate).to be_fully_allocated
    end

    it "is false while funds remain" do
      expect(grant.decorate).not_to be_fully_allocated
    end
  end
end
