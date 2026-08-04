require "rails_helper"

RSpec.describe DuesRegistrationDecorator, type: :decorator do
  def term(cost_cents: 2_500, start_date: Date.current, paid: 0)
    record = create(:dues_registration,
      cost_cents: cost_cents,
      start_date: start_date,
      end_date: start_date + 1.year - 1.day)
    create(:allocation, source: create(:payment, amount_cents: paid), allocatable: record, amount: paid) if paid.positive?
    record.reload.decorate
  end

  describe "#status_badge" do
    it "reads Upcoming before the year starts" do
      expect(term(start_date: Date.current + 1.day).status_badge.label).to eq("Upcoming")
    end

    it "reads Paid for a settled year" do
      expect(term(paid: 2_500).status_badge.label).to eq("Paid")
    end

    it "reads Paid for a comped year" do
      expect(term(cost_cents: 0).status_badge.label).to eq("Paid")
    end

    it "shows what's left while inside the grace window" do
      badge = term(start_date: Date.current - 1).status_badge

      expect(badge.label).to eq("$25 due")
      expect(badge.classes).to eq(described_class::BADGE_CLASSES[:amber])
    end

    it "shows what's left after a part payment" do
      expect(term(paid: 1_000, start_date: Date.current - 1).status_badge.label).to eq("$15 due")
    end

    it "reads Overdue past the grace window" do
      badge = term(start_date: Date.current - Dues::GRACE_PERIOD_DAYS - 1).status_badge

      expect(badge.label).to eq("Overdue")
      expect(badge.classes).to eq(described_class::BADGE_CLASSES[:red])
    end

    it "reads Overdue rather than Expired for an unpaid year that has run out" do
      expect(term(start_date: Date.current - 2.years).status_badge.label).to eq("Overdue")
    end

    it "reads Expired for a paid year that has run out" do
      expect(term(cost_cents: 0, start_date: Date.current - 2.years).status_badge.label).to eq("Expired")
    end
  end

  describe "formatting" do
    it "renders the term as a date range" do
      expect(term(start_date: Date.new(2026, 10, 14)).term_range).to eq("Oct 14, 2026 – Oct 13, 2027")
    end

    it "renders money without trailing cents" do
      decorated = term(paid: 1_000)

      expect(decorated.cost).to eq("$25")
      expect(decorated.paid).to eq("$10")
      expect(decorated.remaining).to eq("$15")
    end

    it "knows a comped year" do
      expect(term(cost_cents: 0)).to be_comped
      expect(term).not_to be_comped
    end
  end
end
