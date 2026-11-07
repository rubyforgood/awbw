require "rails_helper"

RSpec.describe "Membership invoice subscribe action", type: :request do
  let(:person) { create(:person, :without_audit) }
  let(:membership) { create(:membership, person:) }
  let(:invoice) do
    create(:membership_invoice, membership:, start_date: Date.current,
      end_date: Date.current + Membership::INVOICE_PERIOD - 1.day, cost_cents: 10_000)
  end

  def add_card
    customer = Pay::Stripe::Customer.create!(owner: person, processor: "stripe",
      processor_id: "cus_test_#{SecureRandom.hex(4)}", default: true)
    Pay::Stripe::PaymentMethod.create!(customer:,
      processor_id: "pm_test_#{SecureRandom.hex(4)}",
      payment_method_type: "card",
      data: { "brand" => "visa", "last4" => "4242" })
  end

  it "offers Pay and Subscribe instead of Pay now to an owner with a balance and no card" do
    sign_in create(:user, person:)

    get membership_invoice_path(invoice)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pay and Subscribe")
    expect(response.body).to include(subscribe_membership_invoice_path(invoice))
    expect(response.body).not_to include("Pay now")
  end

  it "shows Pay now without Subscribe when autopay is on but the last charge failed" do
    add_card
    membership.update!(autopay_on: true)
    invoice.charge_attempts.create!(
      attempt_number: 1,
      status: "failed",
      amount_cents: invoice.remaining_cost,
      attempted_at: Time.current,
      error_code: "card_declined",
      error_message: "Your card was declined."
    )
    sign_in create(:user, person:)

    get membership_invoice_path(invoice)

    expect(response.body).to include("Pay now")
    expect(response.body).not_to include(subscribe_membership_invoice_path(invoice))
  end

  it "shows Pay now without Subscribe once autopay is on with a card" do
    add_card
    membership.update!(autopay_on: true)
    sign_in create(:user, person:)

    get membership_invoice_path(invoice)

    expect(response.body).to include("Pay now")
    expect(response.body).not_to include(subscribe_membership_invoice_path(invoice))
  end

  it "does not offer Subscribe to an admin" do
    sign_in create(:user, :admin)

    get membership_invoice_path(invoice)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(subscribe_membership_invoice_path(invoice))
  end
end
