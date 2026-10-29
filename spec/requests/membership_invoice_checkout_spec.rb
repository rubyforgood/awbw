require "rails_helper"

RSpec.describe "Membership invoice checkout", type: :request do
  let(:person) { create(:person) }
  let(:membership) { create(:membership, person: person) }
  let(:invoice) { create(:membership_invoice, membership: membership, cost_cents: 2_500) }
  let(:fake_session) do
    double(id: "cs_test_123", url: "https://checkout.stripe.com/membership", status: "open")
  end
  let(:processor) { instance_double("Pay::Stripe::Customer") }

  before do
    allow_any_instance_of(Person).to receive(:stripe_payment_processor).and_return(processor)
    allow_any_instance_of(Person).to receive(:stripe_customer).and_return(nil)
    allow(processor).to receive(:checkout).and_return(fake_session)
    sign_in create(:user, person: person)
  end

  it "starts a checkout for the invoice" do
    post membership_invoice_checkout_path(invoice)

    expect(response).to redirect_to(fake_session.url)
    expect(invoice.reload).to be_payment_in_progress
    expect(invoice.checkout_session_id).to eq("cs_test_123")
  end

  it "resumes the in-progress checkout instead of creating another" do
    post membership_invoice_checkout_path(invoice)
    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .with("cs_test_123", {})
      .and_return(fake_session)

    post membership_invoice_checkout_path(invoice)

    expect(response).to redirect_to(fake_session.url)
    expect(processor).to have_received(:checkout).once
  end

  it "refuses a second checkout while a payment is in progress without a session id" do
    invoice.update_column(:payment_in_progress_at, Time.current)

    post membership_invoice_checkout_path(invoice)

    expect(response).to redirect_to(membership_invoice_path(invoice))
    expect(flash[:alert]).to match(/already in progress/)
    expect(processor).not_to have_received(:checkout)
  end

  it "keeps the Pay now control on the invoice while a payment is in progress" do
    post membership_invoice_checkout_path(invoice)

    get membership_invoice_path(invoice)

    expect(response.body).to include("Pay now")
    expect(response.body).not_to include("A payment is already in progress for this invoice")
  end

  it "does not show Pay now on the profile membership card while a payment is in progress" do
    post membership_invoice_checkout_path(invoice)

    get person_path(person)

    expect(response.body).to include("Payment in progress", "View")
    expect(response.body).not_to include("Pay now")
  end

  it "cancels the Stripe checkout and clears the invoice lock" do
    post membership_invoice_checkout_path(invoice)
    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .with("cs_test_123", {})
      .and_return(fake_session)
    allow(Stripe::Checkout::Session).to receive(:expire)
      .with("cs_test_123", {})
      .and_return(double(status: "expired"))

    get cancel_checkout_membership_invoice_path(invoice)

    expect(response).to redirect_to(membership_invoice_path(invoice))
    expect(flash[:notice]).to eq("Payment was cancelled.")
    expect(invoice.reload).not_to be_payment_in_progress
    expect(invoice.checkout_session_id).to be_nil
  end

  it "tells an admin when a customer payment is in progress" do
    invoice.update_column(:payment_in_progress_at, Time.current)
    sign_in create(:user, :admin)

    get membership_invoice_path(invoice)

    expect(response.body).to include("A customer payment is in progress")
    expect(response.body).to include("Payment in progress")
    expect(response.body).not_to include("Charge saved card")
  end
end
