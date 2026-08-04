require "rails_helper"

RSpec.describe Dues::EnsureTerm do
  let(:membership) { create(:dues_membership) }

  describe "creating the first term" do
    it "starts on the date asked for and runs a year" do
      term = described_class.call(dues_membership: membership, covering: Date.new(2026, 10, 14))

      expect(term.start_date).to eq(Date.new(2026, 10, 14))
      expect(term.end_date).to eq(Date.new(2027, 10, 13))
    end

    it "charges the standard rate" do
      term = described_class.call(dues_membership: membership)
      expect(term.cost_cents).to eq(Dues::ANNUAL_COST_CENTS)
    end

    it "charges the membership's own rate when it has one" do
      membership.update!(rate_cents: 1_500)
      expect(described_class.call(dues_membership: membership).cost_cents).to eq(1_500)
    end

    it "charges nothing when told to, for a year covered by training" do
      term = described_class.call(dues_membership: membership, cost_cents: 0)
      expect(term.cost_cents).to eq(0)
    end

    it "honours a zero rate on the membership" do
      membership.update!(rate_cents: 0)
      expect(described_class.call(dues_membership: membership).cost_cents).to eq(0)
    end
  end

  describe "when a term already covers the date" do
    let!(:existing) do
      create(:dues_registration,
        dues_membership: membership,
        start_date: Date.new(2026, 10, 14),
        end_date: Date.new(2027, 10, 13))
    end

    it "returns it rather than creating another" do
      expect {
        expect(described_class.call(dues_membership: membership, covering: Date.new(2027, 1, 1)))
          .to eq(existing)
      }.not_to change(DuesRegistration, :count)
    end

    it "returns it on the term's final day" do
      expect(described_class.call(dues_membership: membership, covering: existing.end_date))
        .to eq(existing)
    end

    it "is idempotent when called twice for the same date" do
      expect {
        2.times { described_class.call(dues_membership: membership, covering: Date.new(2027, 1, 1)) }
      }.not_to change(DuesRegistration, :count)
    end
  end

  describe "renewing" do
    let!(:previous) do
      create(:dues_registration,
        dues_membership: membership,
        start_date: Date.new(2026, 10, 14),
        end_date: Date.new(2027, 10, 13))
    end

    it "starts the day after the previous term ends" do
      term = described_class.call(dues_membership: membership, covering: Date.new(2027, 10, 14))

      expect(term.start_date).to eq(Date.new(2027, 10, 14))
      expect(term.end_date).to eq(Date.new(2028, 10, 13))
    end

    it "creates a term twice running without overlapping" do
      first = described_class.call(dues_membership: membership, covering: Date.new(2027, 10, 14))
      second = described_class.call(dues_membership: membership, covering: first.end_date + 1.day)

      expect(second.start_date).to eq(first.end_date + 1.day)
      expect(membership.dues_registrations.count).to eq(3)
    end
  end

  describe "after a lapse" do
    let!(:long_ago) do
      create(:dues_registration,
        dues_membership: membership,
        start_date: Date.new(2020, 1, 1),
        end_date: Date.new(2020, 12, 31))
    end

    it "starts fresh instead of backfilling the missed years" do
      term = described_class.call(dues_membership: membership, covering: Date.new(2026, 5, 1))

      expect(term.start_date).to eq(Date.new(2026, 5, 1))
      expect(membership.dues_registrations.count).to eq(2)
    end
  end

  describe "a cancelled membership" do
    before { membership.update!(cancelled_at: Time.current) }

    it "creates nothing" do
      expect {
        expect(described_class.call(dues_membership: membership)).to be_nil
      }.not_to change(DuesRegistration, :count)
    end

    it "still returns a term that already covers the date" do
      existing = create(:dues_registration, dues_membership: membership)

      expect(described_class.call(dues_membership: membership)).to eq(existing)
    end
  end
end
