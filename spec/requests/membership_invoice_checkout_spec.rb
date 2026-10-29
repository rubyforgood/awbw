require "rails_helper"

RSpec.describe "Membership invoice checkout", type: :request do
  let(:person) { create(:person) }
  let(:membership) { create(:membership, person: person) }
  let(:invoice) { create(:membership_invoice, membership: membership, cost_cents: 2_500) }
  let(:fake_session) { double(url: "https://checkout.stripe.com/membership") }
  let(:processor) { instance_double("Pay::Stripe::Customer") }
  let(:payment_methods) { double(exists?: false) }

  before do
    allow_any_instance_of(Person).to receive(:set_payment_processor)
    allow_any_instance_of(Person).to receive(:payment_processor).and_return(processor)
    allow(processor).to receive(:checkout).and_return(fake_session)
    allow(processor).to receive(:payment_methods).and_return(payment_methods)
    sign_in create(:user, person: person)
  end

  it "starts a checkout for the invoice" do
    post membership_invoice_checkout_path(invoice)

    expect(response).to redirect_to(fake_session.url)
    expect(invoice.reload).to be_payment_in_progress
  end

  it "refuses a second checkout while the first is still in progress" do
    post membership_invoice_checkout_path(invoice)

    post membership_invoice_checkout_path(invoice)

    expect(response).to redirect_to(membership_invoice_path(invoice))
    expect(flash[:alert]).to match(/already in progress/)
    expect(processor).to have_received(:checkout).once
  end

  it "shows the in-progress state on the invoice instead of a Pay now button" do
    post membership_invoice_checkout_path(invoice)

    get membership_invoice_path(invoice)

    expect(response.body).to include("A payment is already in progress for this invoice")
    expect(response.body).not_to include("Pay now")
  end

  it "shows the in-progress state on the profile membership card" do
    post membership_invoice_checkout_path(invoice)

    get person_path(person)

    expect(response.body).to include("Payment in progress")
    expect(response.body).not_to include("Pays this invoice once")
  end

  it "tells an admin when a customer payment is in progress" do
    allow(processor).to receive(:payment_methods).and_return(double(exists?: true))
    sign_in create(:user, :admin)

    get membership_invoice_path(invoice)
    expect(response.body).to include("Charge saved card")

    invoice.update_column(:payment_in_progress_at, Time.current)
    get membership_invoice_path(invoice)

    expect(response.body).to include("A customer payment is in progress")
    expect(response.body).to include("Payment in progress")
    expect(response.body).not_to include("Charge saved card")
  end
end
