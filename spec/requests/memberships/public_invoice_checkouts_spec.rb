require "rails_helper"

RSpec.describe "Memberships::PublicInvoiceCheckouts", type: :request do
  let(:person) { create(:person, first_name: "Ada", last_name: "Lovelace") }
  let(:membership) { create(:membership, person: person) }
  let(:invoice) { create(:membership_invoice, membership: membership, cost_cents: 2_500) }
  let(:token) { invoice.signed_id(purpose: MembershipInvoice::PAYMENT_TOKEN_PURPOSE) }

  let(:fake_session) { double(url: "https://checkout.stripe.com/membership") }
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
    allow_any_instance_of(Person).to receive(:set_payment_processor)
    allow_any_instance_of(Person).to receive(:payment_processor).and_return(fake_processor)
  end

  describe "GET /memberships/public_invoice_checkouts/:token" do
    it "shows the invoice and a way to pay it" do
      get memberships_public_invoice_checkout_path(token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("INVOICE", "M-#{invoice.id}", "AWBW annual membership", "$25")
      expect(response.body).to include("Pay now")
      expect(response.body).to include('data-turbo="false"')
    end

    it "404s on an unknown token" do
      get memberships_public_invoice_checkout_path("nope")

      expect(response).to have_http_status(:not_found)
    end

    it "does not offer payment once the year is settled" do
      create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: invoice, amount: 2_500)

      get memberships_public_invoice_checkout_path(token)

      expect(response.body).to include("Paid in full")
      expect(response.body).not_to include("Pay now")
    end

    it "explains a cancelled payment on the way back" do
      get memberships_public_invoice_checkout_path(token, cancelled: "1")

      expect(response.body).to include("Payment was cancelled.")
    end
  end

  describe "POST /memberships/public_invoice_checkouts/:token" do
    it "sends the payer to Stripe with the invoice it settles" do
      post memberships_public_invoice_checkout_path(token)

      expect(response).to redirect_to(fake_session.url)
      expect(checkout_args[:mode]).to eq("payment")
      expect(checkout_args[:metadata]).to eq(membership_id: membership.id, membership_invoice_id: invoice.id)
      expect(checkout_args.dig(:line_items, 0, :price_data, :unit_amount)).to eq(2_500)
      expect(checkout_args[:success_url]).to eq(memberships_public_invoice_checkout_url(token, paid: "1"))
      expect(checkout_args[:cancel_url]).to eq(memberships_public_invoice_checkout_url(token, cancelled: "1"))
    end

    it "does not start another checkout for a settled year" do
      create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: invoice, amount: 2_500)

      post memberships_public_invoice_checkout_path(token)

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to match(/already been paid/)
      expect(checkout_args).to be_empty
    end
  end
end
