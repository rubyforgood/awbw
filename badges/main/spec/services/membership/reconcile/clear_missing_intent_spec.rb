require "rails_helper"

RSpec.describe Membership::Reconcile::ClearMissingIntent do
  let(:person) { create(:person, :without_user) }
  let(:membership) { create(:membership, person:) }
  let(:invoice) { create(:membership_invoice, membership:, cost_cents: 1_000) }
  let(:attempt) do
    invoice.charge_attempts.create!(attempt_number: 1, status: "unknown",
      amount_cents: 1_000, attempted_at: 1.hour.ago, payment_intent_id: "pi_missing")
  end

  it "clears a PaymentIntent Stripe no longer has and fails the attempt" do
    allow(Pay::Payment).to receive(:from_id)
      .and_raise(Stripe::InvalidRequestError.new("No such payment_intent", nil))

    result = described_class.call(attempt:)

    expect(result).to be_success
    expect(attempt.reload).to have_attributes(
      status: "failed",
      payment_intent_id: nil,
      error_code: "intent_not_found",
      next_attempt_on: Date.current + 1.day
    )
  end

  it "refuses when Stripe still has the PaymentIntent" do
    intent = Stripe::PaymentIntent.construct_from(
      id: "pi_missing", object: "payment_intent", status: "processing",
      amount: 1_000, currency: "usd"
    )
    allow(Pay::Payment).to receive(:from_id).and_return(Pay::Payment.new(intent))

    result = described_class.call(attempt:)

    expect(result).not_to be_success
    expect(attempt.reload).to be_unknown
  end

  it "leaves the attempt alone on a transient Stripe error" do
    allow(Pay::Payment).to receive(:from_id)
      .and_raise(Stripe::APIConnectionError.new("Stripe is down"))

    result = described_class.call(attempt:)

    expect(result).not_to be_success
    expect(attempt.reload).to be_unknown
  end

  it "refuses an attempt with no PaymentIntent" do
    attempt.update!(payment_intent_id: nil)

    result = described_class.call(attempt:)

    expect(result).not_to be_success
  end
end
