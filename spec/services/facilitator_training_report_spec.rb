require "rails_helper"

RSpec.describe FacilitatorTrainingReport do
  describe "per-event columns" do
    subject(:report) { described_class.new([ event ]) }

    let(:event) { create(:event, facilitator_training: true, cost_cents: 50_000, start_date: Date.new(2025, 3, 1)) }
    let(:person1) { create(:person) }
    let(:person2) { create(:person) }

    let!(:reg1) { create(:event_registration, event: event, registrant: person1, status: "registered") }
    let!(:reg2) { create(:event_registration, event: event, registrant: person2, status: "registered") }

    before do
      # A cancelled registration whose trainee count and scholarship must be ignored.
      cancelled = create(:event_registration, event: event, registrant: create(:person), status: "cancelled")
      ignored = create(:scholarship, recipient: cancelled.registrant, amount_cents: 9_999, grant: create(:grant))
      create(:allocation, source: ignored, allocatable: cancelled, amount: 9_999)

      funded = create(:scholarship, recipient: person1, amount_cents: 4_000, grant: create(:grant))
      create(:allocation, source: funded, allocatable: reg1, amount: 4_000)

      unfunded = create(:scholarship, recipient: person2, amount_cents: 2_000, grant: nil)
      create(:allocation, source: unfunded, allocatable: reg2, amount: 2_000)
    end

    let(:column) { report.years.first.columns.first }

    it "splits scholarship dollars into funded vs unfunded" do
      expect(column.funded_cents).to eq(4_000)
      expect(column.unfunded_cents).to eq(2_000)
      expect(column.scholarship_cents).to eq(6_000)
    end

    it "splits scholarship award counts into funded vs unfunded" do
      expect(column.funded_count).to eq(1)
      expect(column.unfunded_count).to eq(1)
      expect(column.scholarship_count).to eq(2)
    end

    it "counts only active registrations as trainees" do
      expect(column.trainee_count).to eq(2)
    end

    it "labels the column from the event" do
      expect(column.label).to eq(event.decorate.compact_label)
    end
  end

  describe "trainee format split" do
    let(:scheduled) { create(:event, facilitator_training: true, on_demand: false, start_date: Date.new(2025, 3, 1)) }
    let(:on_demand) { create(:event, facilitator_training: true, on_demand: true, start_date: Date.new(2025, 7, 1)) }

    subject(:report) { described_class.new([ scheduled, on_demand ]) }

    before do
      2.times { create(:event_registration, event: scheduled, registrant: create(:person), status: "registered") }
      3.times { create(:event_registration, event: on_demand, registrant: create(:person), status: "registered") }
    end

    let(:group) { report.years.first }

    it "totals scheduled trainees under 2-Day and self-paced under On-Demand" do
      expect(group.two_day_trainee_count).to eq(2)
      expect(group.on_demand_trainee_count).to eq(3)
    end

    it "sums both formats into the overall trainee total" do
      expect(group.trainee_count).to eq(5)
    end
  end

  describe "grouping and totals" do
    let(:e2024) { create(:event, facilitator_training: true, start_date: Date.new(2024, 5, 1)) }
    let(:e2025a) { create(:event, facilitator_training: true, cost_cents: 50_000, start_date: Date.new(2025, 3, 1)) }
    let(:e2025b) { create(:event, facilitator_training: true, start_date: Date.new(2025, 11, 1)) }

    subject(:report) { described_class.new([ e2025b, e2024, e2025a ]) }

    before do
      person = create(:person)
      reg = create(:event_registration, event: e2025a, registrant: person, status: "registered")
      funded = create(:scholarship, recipient: person, amount_cents: 5_000, grant: create(:grant))
      create(:allocation, source: funded, allocatable: reg, amount: 5_000)
    end

    it "groups by calendar year, newest first" do
      expect(report.years.map(&:year)).to eq([ 2025, 2024 ])
    end

    it "orders each year's columns by start date" do
      expect(report.years.first.columns.map(&:event)).to eq([ e2025a, e2025b ])
    end

    it "sums scholarship dollars across a year's columns" do
      expect(report.years.first.scholarship_cents).to eq(5_000)
    end
  end

  describe "#any?" do
    it "is false with no events" do
      expect(described_class.new([]).any?).to be(false)
    end

    it "is true with at least one event" do
      expect(described_class.new([ create(:event, facilitator_training: true) ]).any?).to be(true)
    end
  end
end
