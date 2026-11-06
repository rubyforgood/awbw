require "rails_helper"

RSpec.describe "Membership reports", type: :request do
  before { sign_in create(:user, :admin) }

  it "defaults to the current year" do
    get membership_reports_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Revenue brought in", "invoices started in #{Date.current.year}",
      "Ended in #{Date.current.year}")
  end

  it "counts revenue for invoices started in the selected year" do
    year = Date.current.year - 1
    person = create(:person, :without_user)
    membership = create(:membership, person:,
      start_date: Date.new(year - 1, 1, 1), end_date: Date.new(year + 1, 12, 31))
    invoice = create(:membership_invoice, membership:, cost_cents: 5_000,
      start_date: Date.new(year, 1, 1), end_date: Date.new(year, 12, 31))
    create(:allocation, allocatable: invoice, amount: 2_000,
      source: create(:payment, person:, amount_cents: 2_000, amount_cents_remaining: 2_000))

    get membership_reports_path(year: year)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Revenue brought in", "$20", "invoices started in #{year}")
  end

  it "drills into collected and outstanding invoices" do
    year = Date.current.year - 1
    person = create(:person, :without_user, first_name: "Invoice", last_name: "Person")
    membership = create(:membership, person:,
      start_date: Date.new(year, 1, 1), end_date: Date.new(year, 12, 31))
    invoice = create(:membership_invoice, membership:, cost_cents: 5_000,
      start_date: Date.new(year, 1, 1), end_date: Date.new(year, 12, 31))
    create(:allocation, allocatable: invoice, amount: 2_000,
      source: create(:payment, person:, amount_cents: 2_000, amount_cents_remaining: 2_000))

    get membership_reports_path(year: year, view: "collected")

    expect(response.body).to include("Collected invoices", "Invoice Person", "$20")

    get membership_reports_path(year: year, view: "outstanding")

    expect(response.body).to include("Outstanding invoices", "Invoice Person", "$30")
  end

  it "drills into closed out and still owing memberships" do
    year = Date.current.year - 1

    paid_person = create(:person, :without_user, first_name: "Paid", last_name: "Ended")
    paid = create(:membership, person: paid_person,
      start_date: Date.new(year - 1, 1, 1), end_date: Date.new(year, 12, 31))
    paid_invoice = create(:membership_invoice, membership: paid, cost_cents: 5_000,
      start_date: Date.new(year - 1, 1, 1), end_date: Date.new(year - 1, 12, 31))
    create(:allocation, allocatable: paid_invoice, amount: 5_000,
      source: create(:payment, person: paid_person, amount_cents: 5_000, amount_cents_remaining: 5_000))

    owing_person = create(:person, :without_user, first_name: "Owing", last_name: "Ended")
    owing = create(:membership, person: owing_person,
      start_date: Date.new(year - 1, 1, 1), end_date: Date.new(year, 12, 31))
    create(:membership_invoice, membership: owing, cost_cents: 5_000,
      start_date: Date.new(year - 1, 1, 1), end_date: Date.new(year - 1, 12, 31))

    get membership_reports_path(year: year, view: "closed_out")

    expect(response.body).to include("Closed out — ended in #{year}", "Paid Ended")
    expect(response.body).not_to include("Owing Ended")

    get membership_reports_path(year: year, view: "still_owing")

    expect(response.body).to include("Still owing — ended in #{year}", "Owing Ended")
    expect(response.body).not_to include("Paid Ended")
  end
end
