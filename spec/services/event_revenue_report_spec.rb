require "rails_helper"

RSpec.describe EventRevenueReport do
  subject(:report) { described_class.new([ event ]) }

  let(:event) { create(:event, cost_cents: 10_000, facilitator_training: true) }
  let(:person1) { create(:person) }
  let(:person2) { create(:person) }

  let!(:reg1) { create(:event_registration, event: event, registrant: person1, status: "registered") }
  let!(:reg2) do
    create(:event_registration, event: event, registrant: person2, status: "registered",
                                ce_credit_requested: true, ce_hours_requested: 3)
  end

  before do
    # A cancelled registration whose money/CE must be ignored everywhere.
    cancelled = create(:event_registration, event: event, registrant: create(:person), status: "cancelled",
                                             ce_credit_requested: true, ce_hours_requested: 6)
    create(:allocation, source: create(:payment, amount_cents: 5_000, amount_cents_remaining: 5_000),
                        allocatable: cancelled, amount: 5_000)

    # reg1: fully covered by a payment plus a funded (grant-backed) scholarship.
    create(:allocation, source: create(:payment, amount_cents: 6_000, amount_cents_remaining: 6_000),
                        allocatable: reg1, amount: 6_000)
    funded = create(:scholarship, recipient: person1, amount_cents: 4_000, grant: create(:grant))
    create(:allocation, source: funded, allocatable: reg1, amount: 4_000)

    # reg2: partial payment plus an unfunded scholarship; still owes registration.
    create(:allocation, source: create(:payment, amount_cents: 3_000, amount_cents_remaining: 3_000),
                        allocatable: reg2, amount: 3_000)
    unfunded = create(:scholarship, recipient: person2, amount_cents: 2_000, grant: nil)
    create(:allocation, source: unfunded, allocatable: reg2, amount: 2_000)
  end

  let(:row) { report.rows.first }

  it "reports registration payments collected" do
    expect(row.registration_payments_cents).to eq(9_000)
  end

  it "reports CE fees as $25 per requested hour, with none paid" do
    expect(row.ce_fees_cents).to eq(7_500)
    expect(row.ce_paid_cents).to eq(0)
  end

  it "splits scholarships by whether a funder backs them" do
    expect(row.funded_scholarship_cents).to eq(4_000)
    expect(row.unfunded_scholarship_cents).to eq(2_000)
  end

  it "counts unpaid registration cost plus the unpaid CE fee as outstanding" do
    # reg1 fully covered (0), reg2 owes 5_000 on registration, plus 7_500 CE.
    expect(row.outstanding_cents).to eq(12_500)
  end

  it "totals all monies, with and without unfunded scholarships" do
    expect(row.total_monies_cents).to eq(22_500)
    expect(row.total_monies_excluding_unfunded_cents).to eq(20_500)
  end

  it "rolls each column up across events" do
    expect(report.registration_payments_cents).to eq(9_000)
    expect(report.ce_fees_cents).to eq(7_500)
    expect(report.funded_scholarship_cents).to eq(4_000)
    expect(report.unfunded_scholarship_cents).to eq(2_000)
    expect(report.outstanding_cents).to eq(12_500)
    expect(report.total_monies_cents).to eq(22_500)
    expect(report.total_monies_excluding_unfunded_cents).to eq(20_500)
  end
end
