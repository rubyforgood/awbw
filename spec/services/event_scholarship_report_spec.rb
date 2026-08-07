require "rails_helper"

RSpec.describe EventScholarshipReport do
  # The report reads (decorated) events, mirroring what the controller passes.
  def report_for(events, **opts)
    described_class.new(events.map(&:decorate), **opts)
  end

  describe "per-training columns" do
    subject(:report) { report_for([ event ]) }

    let(:event) { create(:event, facilitator_training: true, cost_cents: 50_000, start_date: Date.new(2025, 3, 1)) }
    let(:person1) { create(:person) }
    let(:person2) { create(:person) }
    let(:person3) { create(:person) }

    let!(:reg1) { create(:event_registration, event: event, registrant: person1, status: "attended") }
    let!(:reg2) { create(:event_registration, event: event, registrant: person2, status: "attended") }
    let!(:reg3) { create(:event_registration, event: event, registrant: person3, status: "registered") }

    before do
      external = create(:scholarship, recipient: person1, amount_cents: 4_000, grant: create(:grant))
      create(:allocation, source: external, allocatable: reg1, amount: 4_000)

      comped = create(:scholarship, recipient: person2, amount_cents: 2_000, grant: nil)
      create(:allocation, source: comped, allocatable: reg2, amount: 2_000)
    end

    let(:column) { report.years.first.columns.first }

    it "splits scholarship dollars into funded (external grant) vs unfunded" do
      expect(column.funded_cents).to eq(4_000)
      expect(column.unfunded_cents).to eq(2_000)
      expect(column.scholarship_cents).to eq(6_000)
    end

    it "splits scholarship award counts into funded vs unfunded" do
      expect(column.funded_count).to eq(1)
      expect(column.unfunded_count).to eq(1)
      expect(column.scholarship_count).to eq(2)
    end

    it "counts only attended registrations as trainees" do
      # reg1 + reg2 are attended; reg3 is only registered.
      expect(column.attended_count).to eq(2)
    end

    it "labels the column from the event" do
      expect(column.label).to eq(event.decorate.compact_label)
    end
  end

  describe "AWBW-donated grants count as unfunded" do
    subject(:report) { report_for([ event ]) }

    let(:event) { create(:event, facilitator_training: true, cost_cents: 50_000, start_date: Date.new(2025, 3, 1)) }
    let(:person) { create(:person) }
    let!(:reg) { create(:event_registration, event: event, registrant: person, status: "attended") }

    before do
      awbw = create(:organization, name: "A Window Between Worlds")
      awbw_grant = create(:grant, donor: awbw)
      award = create(:scholarship, recipient: person, amount_cents: 3_000, grant: awbw_grant)
      create(:allocation, source: award, allocatable: reg, amount: 3_000)
    end

    let(:column) { report.years.first.columns.first }

    it "treats a grant the org donated to itself as unfunded, not funded" do
      expect(column.funded_cents).to eq(0)
      expect(column.unfunded_cents).to eq(3_000)
      expect(column.funded_count).to eq(0)
      expect(column.unfunded_count).to eq(1)
    end
  end

  describe "funder scoping" do
    let(:event) { create(:event, facilitator_training: true, cost_cents: 50_000, start_date: Date.new(2025, 3, 1)) }
    let(:funder) { create(:organization, name: "Community Trust") }
    let(:person1) { create(:person) }
    let(:person2) { create(:person) }

    before do
      reg1 = create(:event_registration, event: event, registrant: person1, status: "attended")
      reg2 = create(:event_registration, event: event, registrant: person2, status: "attended")

      from_funder = create(:scholarship, recipient: person1, amount_cents: 4_000, grant: create(:grant, donor: funder))
      create(:allocation, source: from_funder, allocatable: reg1, amount: 4_000)

      other = create(:scholarship, recipient: person2, amount_cents: 2_000, grant: create(:grant))
      create(:allocation, source: other, allocatable: reg2, amount: 2_000)
    end

    it "scopes scholarship figures to the given funder" do
      report = described_class.new([ event.decorate ], funder: funder)
      column = report.years.first.columns.first
      expect(column.scholarship_cents).to eq(4_000)
      expect(column.scholarship_count).to eq(1)
    end

    it "counts every funder's scholarships when unscoped" do
      report = described_class.new([ event.decorate ])
      expect(report.years.first.columns.first.scholarship_cents).to eq(6_000)
    end
  end

  describe "attendance split by delivery format" do
    let(:scheduled) { create(:event, facilitator_training: true, on_demand: false, start_date: Date.new(2025, 3, 1)) }
    let(:on_demand) { create(:event, facilitator_training: true, on_demand: true, start_date: Date.new(2025, 7, 1)) }

    subject(:report) { report_for([ scheduled, on_demand ]) }

    before do
      2.times { create(:event_registration, event: scheduled, registrant: create(:person), status: "attended") }
      create(:event_registration, event: scheduled, registrant: create(:person), status: "no_show")
      3.times { create(:event_registration, event: on_demand, registrant: create(:person), status: "attended") }
    end

    let(:group) { report.years.first }

    it "totals attended trainees under Training (scheduled) vs On-demand" do
      expect(group.training_attended_count).to eq(2)
      expect(group.on_demand_attended_count).to eq(3)
    end

    it "sums both formats into the overall attended total (no-shows excluded)" do
      expect(group.attended_count).to eq(5)
    end
  end

  describe "grouping, totals, and featured year" do
    let(:e2024) { create(:event, facilitator_training: true, start_date: Date.new(2024, 5, 1)) }
    let(:e2025a) { create(:event, facilitator_training: true, cost_cents: 50_000, start_date: Date.new(2025, 3, 1)) }
    let(:e2025b) { create(:event, facilitator_training: true, start_date: Date.new(2025, 11, 1)) }

    subject(:report) { report_for([ e2025b, e2024, e2025a ], featured_year: 2025) }

    before do
      person = create(:person)
      reg = create(:event_registration, event: e2025a, registrant: person, status: "attended")
      award = create(:scholarship, recipient: person, amount_cents: 5_000, grant: create(:grant))
      create(:allocation, source: award, allocatable: reg, amount: 5_000)
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

    it "leads with the requested featured year" do
      expect(report.featured_year.year).to eq(2025)
      expect(report.prior_year.year).to eq(2024)
    end

    it "leads with an all-trainings aggregate when no year is featured (all-time)" do
      all_time = report_for([ e2025b, e2024, e2025a ])
      expect(all_time.featured_year.year).to be_nil
      expect(all_time.featured_year.scholarship_cents).to eq(5_000)
      expect(all_time.prior_year).to be_nil
    end

    it "resolves an all-time period to the whole report" do
      period = report.period_scope("all_time")
      expect(period.metrics.scholarship_cents).to eq(5_000)
    end
  end

  describe "#any?" do
    it "is false with no events" do
      expect(described_class.new([]).any?).to be(false)
    end

    it "is true with at least one event" do
      expect(report_for([ create(:event, facilitator_training: true) ]).any?).to be(true)
    end
  end
end
