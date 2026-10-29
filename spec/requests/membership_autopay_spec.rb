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

  it "lets the owner subscribe with a card on file" do
    add_card
    sign_in create(:user, person: person)

    expect { post membership_autopay_path(membership) }
      .to have_enqueued_job(MembershipAutopayJob)

    expect(response).to redirect_to(person_path(person))
    expect(membership.reload.autopay_on?).to be(true)
  end

  it "starts a card setup when there is no card and no issued invoice" do
    allow_any_instance_of(Pay::Stripe::Customer).to receive(:checkout)
      .and_return(double(url: "https://stripe.test/setup"))
    sign_in create(:user, person: person)

    post membership_autopay_path(membership)

    expect(response).to redirect_to("https://stripe.test/setup")
    expect(session[:autopay_setup_membership_id]).to eq(membership.id)
    expect(membership.reload.autopay_on?).to be(false)
  end

  it "pays an issued invoice and saves the card when subscribing" do
    invoice = create(:membership_invoice, membership: membership, start_date: Date.current,
      end_date: Date.current + 1.year - 1.day, cost_cents: 10_000)
    fake_session = double(id: "cs_subscribe", url: "https://stripe.test/subscribe", status: "open")
    checkout_args = {}
    allow_any_instance_of(Pay::Stripe::Customer).to receive(:checkout) do |**args|
      checkout_args.merge!(args)
      fake_session
    end
    sign_in create(:user, person: person)

    post membership_autopay_path(membership)

    expect(response).to redirect_to(fake_session.url)
    expect(checkout_args[:mode]).to eq("payment")
    expect(checkout_args.dig(:payment_intent_data, :setup_future_usage)).to eq("off_session")
    expect(invoice.reload.checkout_session_id).to eq("cs_subscribe")
    expect(session[:autopay_setup_membership_id]).to eq(membership.id)
  end

  it "does not subscribe over an open one-time checkout" do
    invoice = create(:membership_invoice, membership: membership, start_date: Date.current,
      end_date: Date.current + 1.year - 1.day, cost_cents: 10_000)
    invoice.update_column(:checkout_session_id, "cs_open")
    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .with("cs_open", {})
      .and_return(double(status: "open"))
    sign_in create(:user, person: person)

    post membership_autopay_path(membership)

    expect(response).to redirect_to(person_path(person))
    expect(flash[:alert]).to match(/already in progress/)
    expect(membership.reload.autopay_on?).to be(false)
    expect(invoice.reload.checkout_session_id).to eq("cs_open")
  end

  it "turns autopay on after the combined checkout returns" do
    create(:membership_invoice, membership: membership, start_date: Date.current,
      end_date: Date.current + 1.year - 1.day, cost_cents: 10_000)
    allow_any_instance_of(Pay::Stripe::Customer).to receive(:checkout)
      .and_return(double(id: "cs_subscribe", url: "https://stripe.test/subscribe", status: "open"))
    sign_in create(:user, person: person)

    post membership_autopay_path(membership)
    get person_path(person, membership_invoice_checkout: "success", autopay: "1")

    expect(membership.reload.autopay_on?).to be(true)
    expect(flash[:notice]).to match(/Payment received/)
  end

  it "returns to the profile when the combined checkout is cancelled" do
    invoice = create(:membership_invoice, membership: membership, start_date: Date.current,
      end_date: Date.current + 1.year - 1.day, cost_cents: 10_000)
    allow_any_instance_of(Pay::Stripe::Customer).to receive(:checkout)
      .and_return(double(id: "cs_subscribe", url: "https://stripe.test/subscribe", status: "open"))
    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .with("cs_subscribe", {})
      .and_return(double(status: "open"))
    allow(Stripe::Checkout::Session).to receive(:expire)
      .with("cs_subscribe", {})
      .and_return(double(status: "expired"))
    sign_in create(:user, person: person)

    post membership_autopay_path(membership)
    get cancel_checkout_membership_invoice_path(invoice, return_to: "autopay")

    expect(response).to redirect_to(person_path(person, autopay_setup: "cancelled"))
    expect(invoice.reload.checkout_session_id).to be_nil
  end

  it "lets an admin turn autopay off" do
    membership.update!(autopay_on: true)
    sign_in create(:user, :admin)

    delete membership_autopay_path(membership)

    expect(response).to redirect_to(membership_path(membership))
    expect(membership.reload.autopay_on?).to be(false)
  end

  it "does not let an admin subscribe" do
    sign_in create(:user, :admin)

    expect { post membership_autopay_path(membership) }.not_to have_enqueued_job(MembershipAutopayJob)
    expect(membership.reload.autopay_on?).to be(false)
  end

  it "denies autopay actions while memberships are disabled" do
    sign_in create(:user, person: person)
    allow(Membership).to receive(:enabled?).and_return(false)

    delete membership_autopay_path(membership)

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

    post membership_autopay_path(membership)
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

    post membership_autopay_path(membership)
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

  it "shows automatic payment pending on an upcoming invoice when autopay is ready" do
    add_card
    invoice = upcoming_invoice(autopay_on: true)
    sign_in create(:user, person: person)

    get membership_invoice_path(invoice)

    expect(response.body).to include("Automatic payment pending")
    expect(response.body).not_to include("Scheduled for")
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
