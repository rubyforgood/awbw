require "rails_helper"

RSpec.describe "Membership autopay", type: :request do
  let(:person) { create(:person) }
  let(:membership) { create(:membership, person: person) }

  def upcoming_invoice(autopay_on: false)
    start_date = Date.current + 1.day
    membership = create(:membership, person: person, autopay_on: autopay_on,
      start_date: start_date, end_date: start_date + 1.year - 1.day)
    create(:membership_invoice, membership: membership, start_date: start_date,
      end_date: start_date + 1.year - 1.day, cost_cents: 10_000)
  end

  def add_card
    customer = Pay::Stripe::Customer.create!(owner: person, processor: "stripe",
      processor_id: "cus_test_#{SecureRandom.hex(4)}", default: true)
    Pay::Stripe::PaymentMethod.create!(customer: customer,
      processor_id: "pm_test_#{SecureRandom.hex(4)}",
      payment_method_type: "card",
      data: { "brand" => "visa", "last4" => "4242" })
  end

  it "lets the owner turn autopay on with a card" do
    add_card
    sign_in create(:user, person: person)

    patch membership_autopay_path(membership, autopay_on: "1")

    expect(response).to redirect_to(person_path(person))
    expect(membership.reload.autopay_on?).to be(true)
  end

  it "does not turn autopay on without a card" do
    sign_in create(:user, person: person)

    patch membership_autopay_path(membership, autopay_on: "1")

    expect(response).to redirect_to(person_path(person))
    expect(flash[:alert]).to match(/Add a card/)
    expect(membership.reload.autopay_on?).to be(false)
  end

  it "lets the owner enable autopay through setup when a card exists" do
    add_card
    sign_in create(:user, person: person)

    post membership_autopay_setup_path(membership)

    expect(response).to redirect_to(person_path(person))
    expect(membership.reload.autopay_on?).to be(true)
  end

  it "lets an admin turn autopay off" do
    membership.update!(autopay_on: true)
    sign_in create(:user, :admin)

    patch membership_autopay_path(membership, autopay_on: "0")

    expect(response).to redirect_to(membership_path(membership))
    expect(membership.reload.autopay_on?).to be(false)
  end

  it "does not let an admin turn autopay on" do
    sign_in create(:user, :admin)

    patch membership_autopay_path(membership, autopay_on: "1")

    expect(membership.reload.autopay_on?).to be(false)
  end

  it "denies autopay actions while memberships are disabled" do
    sign_in create(:user, person: person)
    allow(Membership).to receive(:enabled?).and_return(false)

    patch membership_autopay_path(membership, autopay_on: "0")

    expect(response).to redirect_to(root_path)
    expect(membership.reload.autopay_on?).to be(false)
  end

  it "shows the admin turn-off action" do
    membership.update!(autopay_on: true)
    sign_in create(:user, :admin)

    get person_memberships_path(person)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Turn off autopay")
  end

  it "turns autopay on after a successful card setup" do
    allow_any_instance_of(Pay::Stripe::Customer).to receive(:checkout)
      .and_return(double(url: "https://stripe.test/setup"))
    sign_in create(:user, person: person)

    post membership_autopay_setup_path(membership)
    Pay::Stripe::PaymentMethod.create!(customer: person.payment_processor,
      processor_id: "pm_test_#{SecureRandom.hex(4)}",
      payment_method_type: "card",
      data: { "brand" => "visa", "last4" => "4242" })

    get person_path(person, autopay_setup: "success")

    expect(membership.reload.autopay_on?).to be(true)
    expect(flash[:notice]).to match(/Automatic payments are on/)
  end

  it "turns autopay on after setup even before the card is visible" do
    allow_any_instance_of(Pay::Stripe::Customer).to receive(:checkout)
      .and_return(double(url: "https://stripe.test/setup"))
    sign_in create(:user, person: person)

    post membership_autopay_setup_path(membership)
    get person_path(person, autopay_setup: "success")

    expect(membership.reload.autopay_on?).to be(true)
    expect(flash[:notice]).to match(/Automatic payments are on/)
  end

  it "does not display the saved card number but keeps the Stripe portal when a card exists" do
    membership
    add_card
    sign_in create(:user, person: person)

    get person_path(person)

    expect(response.body).to include("Manage card")
    expect(response.body).not_to include("Card on file")
    expect(response.body).not_to include("ending 4242")
  end

  it "shows Pay now on an upcoming invoice when autopay is off" do
    invoice = upcoming_invoice
    sign_in create(:user, person: person)

    get membership_invoice_path(invoice)

    expect(response.body).to include("Pay now")
    expect(response.body).not_to include("Scheduled for")
  end

  it "shows the scheduled message on an upcoming invoice when autopay is ready" do
    add_card
    invoice = upcoming_invoice(autopay_on: true)
    sign_in create(:user, person: person)

    get membership_invoice_path(invoice)

    expect(response.body).to include("Scheduled for")
    expect(response.body).not_to include("Pay now")
  end

  it "tells an admin when a customer payment is in progress" do
    invoice = upcoming_invoice
    invoice.update_column(:payment_in_progress_at, Time.current)
    sign_in create(:user, :admin)

    get membership_invoice_path(invoice)

    expect(response.body).to include("A customer payment is in progress")
    expect(response.body).to include("Payment in progress")
    expect(response.body).not_to include("Charge saved card")
  end

  it "does not let the owner open the membership admin page" do
    sign_in create(:user, person: person)

    get membership_path(membership)

    expect(response).to redirect_to(root_path)
  end
end
