require "rails_helper"

RSpec.describe "Profile membership invoices", type: :request do
  let(:person) { create(:person) }
  let(:today) { Date.current }

  def invoice_for(membership, start_date, cost_cents: 10_000)
    create(:membership_invoice, membership:, start_date:,
      end_date: start_date + Membership::INVOICE_PERIOD - 1.day, cost_cents:)
  end

  def period(invoice)
    "#{invoice.start_date.strftime('%b %-d, %Y')} – #{invoice.end_date.strftime('%b %-d, %Y')}"
  end

  it "shows current and upcoming invoices, including a paid current invoice" do
    membership = create(:membership, person:, start_date: today, end_date: today + 2.years - 1.day)
    current = invoice_for(membership, today)
    upcoming = invoice_for(membership, today + 1.year)
    create(:allocation,
      source: create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000),
      allocatable: current, amount: 10_000)

    sign_in create(:user, person:)
    get person_path(person)

    expect(response.body).to include(period(current), period(upcoming), "Receipt", "View")
    expect(response.body).not_to include("Pay now")
  end

  it "keeps an older unpaid invoice visible" do
    membership = create(:membership, person:, start_date: today - 1.year,
      end_date: today + 2.years - 1.day)
    past = invoice_for(membership, today - 1.year)
    invoice_for(membership, today)
    invoice_for(membership, today + 1.year)

    sign_in create(:user, person:)
    get person_path(person)

    expect(response.body).to include(period(past), "Overdue")
  end
end
