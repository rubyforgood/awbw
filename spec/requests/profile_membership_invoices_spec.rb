require "rails_helper"

RSpec.describe "Profile membership invoices", type: :request do
  let(:person) { create(:person) }
  let(:today) { Date.current }

  def add_card(person)
    customer = Pay::Stripe::Customer.create!(
      owner: person,
      processor: "stripe",
      processor_id: "cus_test_#{SecureRandom.hex(4)}",
      default: true
    )
    Pay::Stripe::PaymentMethod.create!(
      customer:,
      processor_id: "pm_test_#{SecureRandom.hex(4)}",
      payment_method_type: "card",
      data: { "brand" => "visa", "last4" => "4242" }
    )
  end

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

    expect(response.body).to include(period(current), period(upcoming), "Receipt", "Pay now")
  end

  it "shows automatic payment pending on an upcoming invoice when autopay is ready" do
    add_card(person)
    membership = create(:membership, person:, start_date: today + 1.day,
      end_date: today + 1.year, autopay_on: true)
    invoice_for(membership, today + 1.day)

    sign_in create(:user, person:)
    get person_path(person)

    expect(response.body).to include("Automatic payment pending")
    expect(response.body).not_to include("Scheduled for")
    expect(response.body).not_to include("Pay now")
  end

  it "offers Pay now on an upcoming invoice when autopay has no card" do
    membership = create(:membership, person:, start_date: today + 1.day,
      end_date: today + 1.year, autopay_on: true)
    invoice_for(membership, today + 1.day)

    sign_in create(:user, person:)
    get person_path(person)

    expect(response.body).to include("Pay now")
    expect(response.body).not_to include("Scheduled for")
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
