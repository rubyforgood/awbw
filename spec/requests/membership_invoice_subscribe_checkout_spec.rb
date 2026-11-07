require "rails_helper"

RSpec.describe "Membership invoice Pay and Subscribe", type: :request do
  let(:person) { create(:person, :without_audit) }
  let(:membership) { create(:membership, person:) }
  let(:invoice) do
    create(:membership_invoice, membership:, start_date: Date.current,
      end_date: Date.current + Membership::INVOICE_PERIOD - 1.day, cost_cents: 10_000)
  end

  def stub_checkout(args = {})
    allow_any_instance_of(Pay::Stripe::Customer).to receive(:checkout) do |**kwargs|
      args.merge!(kwargs)
      double(id: "cs_subscribe", url: "https://stripe.test/subscribe", status: "open")
    end
  end

  it "charges the invoice and saves the card for future automatic payments" do
    checkout_args = {}
    stub_checkout(checkout_args)
    sign_in create(:user, person:)

    post subscribe_membership_invoice_path(invoice)

    expect(response).to redirect_to("https://stripe.test/subscribe")
    expect(checkout_args[:mode]).to eq("payment")
    expect(checkout_args.dig(:payment_intent_data, :setup_future_usage)).to eq("off_session")
    expect(checkout_args[:cancel_url]).to eq(cancel_checkout_membership_invoice_url(invoice))
    expect(invoice.reload.checkout_session_id).to eq("cs_subscribe")
    expect(session[:autopay_setup_membership_id]).to eq(membership.id)
  end

  it "does not charge an invoice with no balance" do
    create(:allocation,
      source: create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000),
      allocatable: invoice, amount: 10_000)
    sign_in create(:user, person:)

    post subscribe_membership_invoice_path(invoice)

    expect(response).to redirect_to(membership_invoice_path(invoice))
    expect(flash[:alert]).to match(/no balance/)
    expect(invoice.reload.checkout_session_id).to be_nil
  end

  it "does not let someone else pay and subscribe" do
    sign_in create(:user)

    post subscribe_membership_invoice_path(invoice)

    expect(response).to have_http_status(:redirect)
    expect(invoice.reload.checkout_session_id).to be_nil
  end

  it "does not let a membership with renewal off pay and subscribe" do
    membership.update!(renewal_off_at: Time.current)
    sign_in create(:user, person:)

    post subscribe_membership_invoice_path(invoice)

    expect(response).to have_http_status(:redirect)
    expect(invoice.reload.checkout_session_id).to be_nil
  end

  it "turns autopay on when the checkout returns" do
    stub_checkout
    sign_in create(:user, person:)

    post subscribe_membership_invoice_path(invoice)
    get person_path(person, membership_invoice_checkout: "success", autopay: "1")

    expect(membership.reload.autopay_on?).to be(true)
    expect(flash[:notice]).to match(/Payment received/)
  end

  it "returns to the invoice and clears the setup session when the checkout is cancelled" do
    stub_checkout
    sign_in create(:user, person:)

    post subscribe_membership_invoice_path(invoice)
    expect(session[:autopay_setup_membership_id]).to eq(membership.id)

    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .with("cs_subscribe")
      .and_return(double(status: "open"))
    allow(Stripe::Checkout::Session).to receive(:expire)
      .with("cs_subscribe")
      .and_return(double(status: "expired"))

    get cancel_checkout_membership_invoice_path(invoice)

    expect(response).to redirect_to(membership_invoice_path(invoice))
    expect(flash[:notice]).to eq("Payment was cancelled.")
    expect(session[:autopay_setup_membership_id]).to be_nil
    expect(invoice.reload.checkout_session_id).to be_nil
  end
end
