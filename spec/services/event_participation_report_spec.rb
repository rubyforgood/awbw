require "rails_helper"

RSpec.describe EventParticipationReport do
  describe "per-event outcome counts" do
    subject(:report) { described_class.new([ event ]) }

    let(:event) { create(:event) }

    before do
      create(:event_registration, event: event, status: "attended")
      create(:event_registration, event: event, status: "attended")
      create(:event_registration, event: event, status: "incomplete_attendance")
      create(:event_registration, event: event, status: "no_show")
      create(:event_registration, event: event, status: "cancelled")
      create(:event_registration, event: event, status: "registered")
    end

    let(:row) { report.rows.first }

    it "counts each outcome by status" do
      expect(row.attended_seats).to eq(2)
      expect(row.count_for("incomplete_attendance")).to eq(1)
      expect(row.count_for("no_show")).to eq(1)
      expect(row.count_for("cancelled")).to eq(1)
      expect(row.count_for("registered")).to eq(1)
      expect(row.count_for("transferred_out")).to eq(0)
    end

    it "totals every registration regardless of outcome" do
      expect(row.total_registrations).to eq(6)
    end

    it "buckets the remaining outcomes into 'other' so the four sum to registrations" do
      expect(row.count_other).to eq(2) # registered + cancelled
      buckets = row.attended_seats + row.count_for("incomplete_attendance") + row.count_for("no_show") + row.count_other
      expect(buckets).to eq(row.total_registrations)
    end

    it "treats attended seats as unique people for a single event" do
      expect(row.unique_people).to eq(row.attended_seats)
    end
  end

  describe "unique people vs seats across events" do
    let(:person) { create(:person) }
    let(:event_a) { create(:event, start_date: Date.new(2026, 3, 1)) }
    let(:event_b) { create(:event, start_date: Date.new(2026, 6, 1)) }

    subject(:report) { described_class.new([ event_a, event_b ], current_year: 2026) }

    before do
      # The same person completes both trainings in 2026: two attended seats,
      # but one person trained.
      create(:event_registration, event: event_a, registrant: person, status: "attended")
      create(:event_registration, event: event_b, registrant: person, status: "attended")
      create(:event_registration, event: event_b, status: "attended")
    end

    it "sums attended seats additively" do
      expect(report.attended_seats).to eq(3)
    end

    it "counts unique people distinctly, not by summing rows" do
      expect(report.unique_people).to eq(2)
    end

    it "counts unique people per year distinctly in the subtotal" do
      year = report.years.first
      expect(year.year).to eq(2026)
      expect(year.attended_seats).to eq(3)
      expect(year.unique_people).to eq(2)
    end
  end

  describe "#training_split" do
    let(:person_both) { create(:person) }
    let(:training) { create(:event, facilitator_training: true, start_date: Date.new(2026, 4, 1)) }
    let(:webinar) { create(:event, facilitator_training: false, start_date: Date.new(2026, 4, 1)) }

    subject(:report) { described_class.new([ training, webinar ], current_year: 2026) }

    before do
      # person_both attends a training and a non-training; two others attend one each.
      create(:event_registration, event: training, registrant: person_both, status: "attended")
      create(:event_registration, event: webinar, registrant: person_both, status: "attended")
      create(:event_registration, event: training, status: "attended")
      create(:event_registration, event: webinar, status: "attended")
    end

    it "counts distinct attendees on each side, counting cross-attenders in both" do
      split = report.training_split
      expect(split[:trainings]).to eq(2)
      expect(split[:non_trainings]).to eq(2)
      # Only three distinct people overall — the cross-attender is in both buckets.
      expect(report.unique_people).to eq(3)
    end

    it "narrows the split to a calendar year" do
      older = create(:event, facilitator_training: true, start_date: Date.new(2025, 4, 1))
      create(:event_registration, event: older, status: "attended")
      scoped = described_class.new([ training, webinar, older ], current_year: 2026)

      expect(scoped.training_split[:trainings]).to eq(3)
      expect(scoped.training_split(year: 2026)[:trainings]).to eq(2)
    end
  end

  describe "#registrations_split" do
    let(:training) { create(:event, facilitator_training: true, start_date: Date.new(2026, 4, 1)) }
    let(:webinar) { create(:event, facilitator_training: false, start_date: Date.new(2026, 4, 1)) }

    subject(:report) { described_class.new([ training, webinar ], current_year: 2026) }

    before do
      create(:event_registration, event: training, status: "attended")
      create(:event_registration, event: training, status: "no_show")
      create(:event_registration, event: webinar, status: "registered")
    end

    it "sums every registration on each side regardless of outcome" do
      split = report.registrations_split
      expect(split[:trainings]).to eq(2)
      expect(split[:non_trainings]).to eq(1)
    end
  end

  describe "#demographics" do
    let(:event) { create(:event, start_date: Date.new(2026, 5, 1)) }
    let(:person) { create(:person) }

    subject(:report) { described_class.new([ event ], current_year: 2026) }

    before do
      registration = create(:event_registration, event: event, registrant: person, status: "attended")
      create(:event_registration_organization, event_registration: registration, organization: create(:organization))
      create(:sectorable_item, sectorable: person, sector: create(:sector))
      create(:address, addressable: person, state: "CA", country: "US")
    end

    it "counts distinct orgs, sectors, states and countries via registrants" do
      reach = report.demographics
      expect(reach.organizations).to eq(1)
      expect(reach.sectors).to eq(1)
      expect(reach.states).to eq(1)
      expect(reach.countries).to eq(1)
    end
  end

  describe "#period_scope" do
    let(:this_year) { create(:event, start_date: Date.new(2026, 5, 1)) }
    let(:last_year) { create(:event, start_date: Date.new(2025, 5, 1)) }

    subject(:report) { described_class.new([ this_year, last_year ], current_year: 2026) }

    before do
      create(:event_registration, event: this_year, status: "attended")
      create(:event_registration, event: last_year, status: "attended")
      create(:event_registration, event: last_year, status: "attended")
    end

    it "resolves this year to the current year's group" do
      period = report.period_scope("this_year")
      expect(period.label).to eq("2026")
      expect(period.year).to eq(2026)
      expect(period.metrics.unique_people).to eq(1)
    end

    it "resolves last year to the prior year's group" do
      period = report.period_scope("last_year")
      expect(period.label).to eq("2025")
      expect(period.metrics.unique_people).to eq(2)
    end

    it "resolves all time to the whole report" do
      period = report.period_scope("all_time")
      expect(period.label).to eq("All time")
      expect(period.year).to be_nil
      expect(period.metrics).to eq(report)
      expect(period.metrics.unique_people).to eq(3)
    end

    it "yields a zeroed group for a year with no events" do
      period = report.period_scope("this_year", current_year: 2030)
      expect(period.label).to eq("2030")
      expect(period.metrics.unique_people).to eq(0)
      expect(period.metrics.total_registrations).to eq(0)
    end
  end

  describe "grouping over time" do
    let(:e2024) { create(:event, start_date: Date.new(2024, 5, 1)) }
    let(:e2025) { create(:event, start_date: Date.new(2025, 5, 1)) }
    let(:e2026) { create(:event, start_date: Date.new(2026, 5, 1)) }

    subject(:report) { described_class.new([ e2026, e2024, e2025 ], current_year: 2026) }

    it "groups events by calendar year, newest first, flagging the current year" do
      expect(report.years.map(&:year)).to eq([ 2026, 2025, 2024 ])
      expect(report.years.first.in_progress).to be(true)
      expect(report.years.last.in_progress).to be(false)
    end

    it "features the current year by default, with the next older year as prior" do
      expect(report.featured_year.year).to eq(2026)
      expect(report.prior_year.year).to eq(2025)
    end

    it "features an explicit year when given" do
      scoped = described_class.new([ e2026, e2024, e2025 ], current_year: 2026, featured_year: 2024)
      expect(scoped.featured_year.year).to eq(2024)
      expect(scoped.prior_year).to be_nil
    end

    it "builds an oldest-to-newest stacked series: attended, partial, no show" do
      series = report.chart_series
      expect(series.map { |s| s[:name] }).to eq([ "Attended", "Partial (1-day)", "No show" ])
      expect(series.first[:data].map(&:first)).to eq(%w[2024 2025 2026])
    end
  end

  describe "an empty report" do
    subject(:report) { described_class.new([]) }

    it "has no rows and reports zero people" do
      expect(report.any?).to be(false)
      expect(report.unique_people).to eq(0)
    end
  end
end
