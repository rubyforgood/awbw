require "rails_helper"

RSpec.describe Membership::Reconcile::Checkout do
  let(:person) { create(:person, :without_user) }
  let(:membership) { create(:membership, person:) }
  let(:invoice) { create(:membership_invoice, membership:, cost_cents: 1_000) }

  before do
    invoice.update_columns(checkout_session_id: "cs_test", payment_in_progress_at: 1.hour.ago)
  end

  it "records a completed, paid checkout and clears the session" do
    intent = Stripe::PaymentIntent.construct_from(
      id: "pi_test", object: "payment_intent", status: "succeeded", amount: 1_000, currency: "usd"
    )
    session = double(status: "complete", payment_status: "paid", payment_intent: intent)
    allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(session)
    allow(Membership::Reconcile::Charge).to receive(:call).and_return(
      Membership::Reconcile::Charge::Result.new(
        status: :applied, payment: nil, pay_charge: nil, allocation: nil,
        message: "Applied $10 to the invoice.", errors: []
      )
    )

    result = described_class.call(invoice:)

    expect(result).to be_success
    expect(invoice.reload.checkout_session_id).to be_nil
  end

  it "clears an expired checkout so the invoice can be paid again" do
    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .and_return(double(status: "expired"))

    result = described_class.call(invoice:)

    expect(result).to be_success
    expect(invoice.reload.checkout_session_id).to be_nil
  end

  it "does not clear a newer checkout session" do
    allow(Stripe::Checkout::Session).to receive(:retrieve) do
      invoice.update_columns(checkout_session_id: "cs_new", payment_in_progress_at: Time.current)
      double(status: "expired")
    end

    result = described_class.call(invoice:)

    expect(result).not_to be_success
    expect(result.errors).to include(/newer checkout/)
    expect(invoice.reload.checkout_session_id).to eq("cs_new")
    expect(invoice.payment_in_progress?).to be(true)
  end

  it "leaves an open checkout alone" do
    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .and_return(double(status: "open"))

    result = described_class.call(invoice:)

    expect(result).not_to be_success
    expect(invoice.reload.checkout_session_id).to eq("cs_test")
  end

  it "clears a stale session Stripe no longer has" do
    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .and_raise(Stripe::InvalidRequestError.new("No such checkout session", nil))

    result = described_class.call(invoice:)

    expect(result).to be_success
    expect(invoice.reload.checkout_session_id).to be_nil
  end

  it "leaves a fresh session alone when Stripe cannot find it" do
    invoice.update_columns(payment_in_progress_at: Time.current)
    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .and_raise(Stripe::InvalidRequestError.new("No such checkout session", nil))

    result = described_class.call(invoice:)

    expect(result).not_to be_success
    expect(invoice.reload.checkout_session_id).to eq("cs_test")
  end

  it "leaves a stale session alone on a transient Stripe error" do
    allow(Stripe::Checkout::Session).to receive(:retrieve)
      .and_raise(Stripe::APIConnectionError.new("Stripe is down"))

    result = described_class.call(invoice:)

    expect(result).not_to be_success
    expect(invoice.reload.checkout_session_id).to eq("cs_test")
  end
end
