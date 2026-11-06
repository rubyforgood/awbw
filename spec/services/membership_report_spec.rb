require "rails_helper"

RSpec.describe MembershipReport do
  def pay(invoice, cents)
    create(:allocation, allocatable: invoice, amount: cents,
      source: create(:payment, person: invoice.person, amount_cents: cents, amount_cents_remaining: cents))
  end

  it "totals revenue, outstanding, and ended members for the year" do
    started_person = create(:person, :without_user)
    started = create(:membership, person: started_person,
      start_date: Date.new(2025, 1, 1), end_date: Date.new(2026, 12, 31))
    started_invoice = create(:membership_invoice, membership: started,
      cost_cents: 10_000, start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31))
    pay(started_invoice, 4_000)
    create(:membership_invoice, membership: started,
      cost_cents: 2_000, start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31))

    paid_person = create(:person, :without_user)
    paid = create(:membership, person: paid_person,
      start_date: Date.new(2024, 1, 1), end_date: Date.new(2025, 12, 31))
    paid_invoice = create(:membership_invoice, membership: paid,
      cost_cents: 5_000, start_date: Date.new(2024, 1, 1), end_date: Date.new(2024, 12, 31))
    pay(paid_invoice, 5_000)

    still_started_person = create(:person, :without_user)
    still_started = create(:membership, person: still_started_person,
      start_date: Date.new(2025, 1, 1), end_date: Date.new(2026, 12, 31))
    still_started_invoice = create(:membership_invoice, membership: still_started,
      cost_cents: 3_000, start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31))
    pay(still_started_invoice, 3_000)

    owing_person = create(:person, :without_user)
    owing = create(:membership, person: owing_person,
      start_date: Date.new(2024, 1, 1), end_date: Date.new(2025, 12, 31))
    create(:membership_invoice, membership: owing,
      cost_cents: 2_000, start_date: Date.new(2024, 1, 1), end_date: Date.new(2024, 12, 31))

    report = described_class.new(year: 2025)

    expect(report.revenue_cents).to eq(7_000)
    expect(report.outstanding_cents).to eq(6_000)
    expect(report.ended_count).to eq(2)
    expect(report.closed_out_count).to eq(1)
    expect(report.still_owing_count).to eq(1)
  end

  it "attributes revenue to the invoice start year" do
    person = create(:person, :without_user)
    membership = create(:membership, person:,
      start_date: Date.new(2024, 1, 1), end_date: Date.new(2026, 12, 31))

    [ 2024, 2025, 2026 ].each do |year|
      invoice = create(:membership_invoice, membership:,
        cost_cents: 5_000, start_date: Date.new(year, 1, 1), end_date: Date.new(year, 12, 31))
      pay(invoice, 5_000)
    end

    report = described_class.new(year: 2025)

    expect(report.revenue_cents).to eq(5_000)
    expect(report.outstanding_cents).to eq(0)
  end
end
