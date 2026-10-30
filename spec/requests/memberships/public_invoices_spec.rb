require "rails_helper"

RSpec.describe "Memberships::PublicInvoices", type: :request do
  let(:person) { create(:person, :without_audit, first_name: "Ada", last_name: "Lovelace") }
  let(:membership) { create(:membership, person: person) }
  let(:invoice) { create(:membership_invoice, membership: membership, cost_cents: 2_500) }
  let(:token) { invoice.signed_id(purpose: MembershipInvoice::PAYMENT_TOKEN_PURPOSE) }

  let(:fake_session) do
    double(id: "cs_test_123", url: "https://checkout.stripe.com/membership", status: "open")
  end
  let(:checkout_args) { {} }
  let(:fake_processor) do
    instance_double("Pay::Stripe::Customer").tap do |processor|
      allow(processor).to receive(:checkout) do |**args|
        checkout_args.merge!(args)
        fake_session
      end
    end
  end

  before do
    allow_any_instance_of(Person).to receive(:stripe_payment_processor).and_return(fake_processor)
    allow_any_instance_of(Person).to receive(:stripe_customer).and_return(nil)
  end

  describe "GET /memberships/public_invoices/:token" do
    it "shows the invoice and a way to pay it" do
      get memberships_public_invoice_path(token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("INVOICE", "M-#{invoice.id}", "AWBW annual membership", "$25")
      expect(response.body).to include("Pay now")
      expect(response.body).to include('data-turbo="false"')
    end

    it "404s on an unknown token" do
      get memberships_public_invoice_path("nope")

      expect(response).to have_http_status(:not_found)
    end

    it "does not offer payment once the year is settled" do
      create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: invoice, amount: 2_500)

      get memberships_public_invoice_path(token)

      expect(response.body).to include("Paid in full")
      expect(response.body).not_to include("Pay now")
    end

    it "explains a cancelled payment on the way back" do
      get memberships_public_invoice_path(token, cancelled: "1")

      expect(response.body).to include("Payment was cancelled.")
    end

    it "hides the checkout controls while a payment is in progress without a session id" do
      invoice.mark_payment_in_progress!

      get memberships_public_invoice_path(token)

      expect(response.body).not_to include("A payment is already in progress for this invoice")
      expect(response.body).not_to include("Pay now")
    end

    it "keeps the Pay now control while a checkout session is stored" do
      invoice.update_columns(payment_in_progress_at: Time.current, checkout_session_id: "cs_test_123")

      get memberships_public_invoice_path(token)

      expect(response.body).to include("Pay now")
    end
  end

  describe "POST /memberships/public_invoices/:token/checkout" do
    it "sends the payer to Stripe with the invoice it settles" do
      post checkout_memberships_public_invoice_path(token)

      expect(response).to redirect_to(fake_session.url)
      expect(checkout_args[:mode]).to eq("payment")
      expect(checkout_args[:metadata]).to eq(membership_id: membership.id, membership_invoice_id: invoice.id)
      expect(checkout_args.dig(:line_items, 0, :price_data, :unit_amount)).to eq(2_500)
      expect(checkout_args[:success_url]).to eq(memberships_public_invoice_url(token, paid: "1"))
      expect(checkout_args[:cancel_url]).to eq(cancel_checkout_memberships_public_invoice_url(token))
    end

    it "resumes an open checkout instead of creating another" do
      invoice.update_columns(payment_in_progress_at: Time.current, checkout_session_id: "cs_test_123")
      allow(Stripe::Checkout::Session).to receive(:retrieve)
        .with("cs_test_123")
        .and_return(fake_session)

      post checkout_memberships_public_invoice_path(token)

      expect(response).to redirect_to(fake_session.url)
      expect(checkout_args).to be_empty
    end

    it "does not start another checkout for a settled year" do
      create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: invoice, amount: 2_500)

      post checkout_memberships_public_invoice_path(token)

      expect(response).to redirect_to(memberships_public_invoice_path(token))
      expect(flash[:notice]).to match(/already been paid/)
      expect(checkout_args).to be_empty
    end

    it "does not start another checkout while a payment is in progress without a session id" do
      invoice.mark_payment_in_progress!

      post checkout_memberships_public_invoice_path(token)

      expect(response).to redirect_to(memberships_public_invoice_path(token))
      expect(flash[:alert]).to match(/already in progress/)
      expect(checkout_args).to be_empty
    end

    it "cancels the Stripe checkout and clears the invoice lock" do
      invoice.update_columns(payment_in_progress_at: Time.current, checkout_session_id: "cs_test_123")
      allow(Stripe::Checkout::Session).to receive(:retrieve)
        .with("cs_test_123")
        .and_return(fake_session)
      allow(Stripe::Checkout::Session).to receive(:expire)
        .with("cs_test_123")
        .and_return(double(status: "expired"))

      get cancel_checkout_memberships_public_invoice_path(token)

      expect(response).to redirect_to(memberships_public_invoice_path(token))
      expect(flash[:notice]).to eq("Payment was cancelled.")
      expect(invoice.reload).not_to be_payment_in_progress
      expect(invoice.checkout_session_id).to be_nil
    end
  end
end
