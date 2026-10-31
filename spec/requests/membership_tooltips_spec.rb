require "rails_helper"

RSpec.describe "Membership tooltips", type: :request do
  around { |example| Time.use_zone("Pacific Time (US & Canada)") { example.run } }

  let(:person) { create(:person, :without_audit) }
  let(:membership) { create(:membership, person: person) }

  def add_card
    customer = Pay::Stripe::Customer.create!(owner: person, processor: "stripe",
      processor_id: "cus_test_#{SecureRandom.hex(4)}", default: true)
    Pay::Stripe::PaymentMethod.create!(customer: customer,
      processor_id: "pm_test_#{SecureRandom.hex(4)}",
      payment_method_type: "card",
      data: { "brand" => "visa", "last4" => "4242" })
  end

  it "shows action and status tooltips to an admin" do
    sign_in create(:user, :admin)

    get membership_path(membership)

    expect(response).to have_http_status(:ok)
    body = CGI.unescapeHTML(response.body)
    expect(body).to include("Creates the next year's invoice now. The ending invoice must be paid in full.")
    expect(body).to include("Stops future invoices and automatic payments. The current term remains in place.")
    expect(body).to include("Current membership covers today.")
  end

  it "shows payment and autopay tooltips to the member" do
    create(:membership_invoice, membership: membership, start_date: Date.current,
      end_date: Date.current + 1.year - 1.day, cost_cents: 10_000)
    sign_in create(:user, person: person)

    get person_path(person)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Subscribe")
    expect(response.body).to include("Saves your card, pays the issued invoice now, and turns on automatic payments.")
    expect(response.body).to include("Automatic payments are off. Invoices must be paid manually.")
    expect(response.body).not_to include("Manage card")
    expect(response.body).not_to include("Card on file")
  end

  it "shows the Subscribe tooltip when a card is already on file" do
    create(:membership_invoice, membership: membership, start_date: Date.current,
      end_date: Date.current + 1.year - 1.day, cost_cents: 10_000)
    add_card
    sign_in create(:user, person: person)

    get person_path(person)

    expect(response.body).to include("Turns on automatic payments and charges any issued invoice.")
  end

  it "shows payment in progress on the membership card instead of Pay now" do
    invoice = create(:membership_invoice, membership: membership, start_date: Date.current,
      end_date: Date.current + 1.year - 1.day, cost_cents: 10_000)
    invoice.mark_payment_in_progress!
    sign_in create(:user, person: person)

    get person_path(person)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Payment in progress")
    expect(response.body).not_to include("Pays this invoice once")
  end
end
