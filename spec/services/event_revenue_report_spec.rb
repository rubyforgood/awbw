require "rails_helper"

RSpec.describe EventRevenueReport do
  describe "per-event figures" do
    subject(:report) { described_class.new([ event ]) }

    let(:event) { create(:event, cost_cents: 10_000, facilitator_training: true) }
    let(:person1) { create(:person) }
    let(:person2) { create(:person) }

    let!(:reg1) { create(:event_registration, event: event, registrant: person1, status: "registered") }
    let!(:reg2) do
      create(:event_registration, event: event, registrant: person2, status: "registered")
    end

    before do
      # reg2's CE fee: a $75 CE registration with no payment — outstanding, not collected.
      create(:continuing_education_registration, event_registration: reg2, cost_cents: 7_500)

      # A cancelled registration whose money/CE must be ignored everywhere.
      cancelled = create(:event_registration, event: event, registrant: create(:person), status: "cancelled")
      create(:continuing_education_registration, event_registration: cancelled, cost_cents: 12_000)
      create(:allocation, source: create(:payment, amount_cents: 5_000, amount_cents_remaining: 5_000),
                          allocatable: cancelled, amount: 5_000)

      # reg1: covered by a payment plus a funded (grant-backed) scholarship.
      create(:allocation, source: create(:payment, amount_cents: 6_000, amount_cents_remaining: 6_000),
                          allocatable: reg1, amount: 6_000)
      funded = create(:scholarship, recipient: person1, amount_cents: 4_000, grant: create(:grant))
      create(:allocation, source: funded, allocatable: reg1, amount: 4_000)

      # reg2: partial payment, an unfunded scholarship, and a discount; still owes.
      create(:allocation, source: create(:payment, amount_cents: 3_000, amount_cents_remaining: 3_000),
                          allocatable: reg2, amount: 3_000)
      unfunded = create(:scholarship, recipient: person2, amount_cents: 2_000, grant: nil)
      create(:allocation, source: unfunded, allocatable: reg2, amount: 2_000)
      create(:allocation, source: create(:discount, amount_cents: 1_000), allocatable: reg2, amount: 1_000)
    end

    let(:row) { report.rows.first }

    it "reports the raw components" do
      expect(row.registration_payments_cents).to eq(9_000)
      expect(row.ce_paid_cents).to eq(0)
      expect(row.ce_outstanding_cents).to eq(7_500)
      expect(row.funded_scholarship_cents).to eq(4_000)
      expect(row.unfunded_scholarship_cents).to eq(2_000)
      expect(row.discount_cents).to eq(1_000)
      expect(row.registration_outstanding_cents).to eq(4_000)
    end

    it "collects registration payments plus CE paid (this event's CE is unpaid)" do
      expect(row.fees_cents).to eq(9_000)
    end

    it "owes registration plus uncollected CE as outstanding" do
      expect(row.outstanding_cents).to eq(11_500)
    end

    it "buckets org subsidy (unfunded scholarships + discounts)" do
      expect(row.org_subsidy_cents).to eq(3_000)
    end

    it "nets fees + funded scholarships against org subsidy" do
      expect(row.net_cents).to eq(10_000)
    end

    it "projects total expected as net plus outstanding" do
      expect(row.total_expected_cents).to eq(21_500)
    end

    it "rolls the buckets up across the report" do
      expect(report.fees_cents).to eq(9_000)
      expect(report.outstanding_cents).to eq(11_500)
      expect(report.org_subsidy_cents).to eq(3_000)
      expect(report.net_cents).to eq(10_000)
      expect(report.total_expected_cents).to eq(21_500)
    end
  end

  describe "collected CE payments" do
    subject(:report) { described_class.new([ event ]) }

    # Free-registration event to isolate CE money from registration fees.
    let(:event) { create(:event, cost_cents: 0) }
    let(:person) { create(:person) }
    let!(:registration) { create(:event_registration, event: event, registrant: person, status: "registered") }
    let(:row) { report.rows.first }

    before do
      # A $60 CE registration with $50 collected: $50 is fees, $10 stays outstanding.
      ce = create(:continuing_education_registration, event_registration: registration, cost_cents: 6_000)
      create(:allocation, source: create(:payment, amount_cents: 5_000, amount_cents_remaining: 5_000),
                          allocatable: ce, amount: 5_000)
    end

    it "counts CE cash collected as fees" do
      expect(row.ce_paid_cents).to eq(5_000)
      expect(row.fees_cents).to eq(5_000)
    end

    it "leaves only the uncollected CE balance outstanding" do
      expect(row.ce_outstanding_cents).to eq(1_000)
      expect(row.outstanding_cents).to eq(1_000)
    end

    it "counts collected CE toward money in and net" do
      expect(row.money_in_cents).to eq(5_000)
      expect(row.net_cents).to eq(5_000)
    end
  end

  # A discounted CE fee is cost the org absorbs, same as a discounted
  # registration fee — it must land in org subsidy rather than disappear between
  # "collected" and "owed".
  describe "discounted CE fees" do
    subject(:report) { described_class.new([ event ]) }

    let(:event) { create(:event, cost_cents: 0) }
    let!(:registration) { create(:event_registration, event: event, registrant: create(:person), status: "registered") }
    let(:row) { report.rows.first }

    before do
      # A $60 CE registration comped in full.
      ce = create(:continuing_education_registration, event_registration: registration, cost_cents: 6_000)
      create(:allocation, source: create(:discount, amount_cents: 6_000), allocatable: ce, amount: 6_000)
    end

    it "counts the comped CE fee as org subsidy, not as collected or owed" do
      expect(row.discount_cents).to eq(6_000)
      expect(row.org_subsidy_cents).to eq(6_000)
      expect(row.ce_paid_cents).to eq(0)
      expect(row.ce_outstanding_cents).to eq(0)
      expect(row.net_cents).to eq(-6_000)
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

    it "aggregates all events when no year is featured (all-time), with no prior delta" do
      expect(report.featured_year.year).to be_nil
      expect(report.prior_year).to be_nil
    end

    it "features an explicit year when given (e.g. the event navigated from)" do
      scoped = described_class.new([ e2026, e2024, e2025 ], current_year: 2026, featured_year: 2024)
      expect(scoped.featured_year.year).to eq(2024)
      expect(scoped.prior_year).to be_nil
    end

    it "falls back to the most recent year when the featured year has no events" do
      scoped = described_class.new([ e2024, e2025 ], current_year: 2026, featured_year: 2026)
      expect(scoped.featured_year.year).to eq(2025)
    end

    it "builds an oldest-to-newest stacked series: fees, funded scholarships, subsidy" do
      series = report.chart_series
      expect(series.map { |s| s[:name] }).to eq([ "Fees", "Funded scholarships", "Org subsidy" ])
      expect(series.first[:data].map(&:first)).to eq(%w[2024 2025 2026])
    end
  end
end
