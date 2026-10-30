require "rails_helper"

RSpec.describe Membership::Reconcile::CancelIntent do
  let(:person) { create(:person) }
  let(:membership) { create(:membership, person:) }
  let(:invoice) { create(:membership_invoice, membership:, cost_cents: 1_000) }
  let(:attempt) do
    invoice.charge_attempts.create!(attempt_number: 1, status: "needs_action",
      amount_cents: 1_000, attempted_at: 1.hour.ago, payment_intent_id: "pi_test")
  end

  def intent(status:)
    Stripe::PaymentIntent.construct_from(
      id: "pi_test", object: "payment_intent", status:, amount: 1_000, currency: "usd"
    )
  end

  it "cancels the intent in Stripe and marks the attempt failed" do
    allow(Pay::Payment).to receive(:from_id).and_return(Pay::Payment.new(intent(status: "requires_action")))
    allow(Stripe::PaymentIntent).to receive(:cancel).and_return(intent(status: "canceled"))

    result = described_class.call(attempt:)

    expect(result).to be_success
    expect(attempt.reload).to have_attributes(status: "failed", error_code: "canceled_by_admin")
  end

  it "cancels an unknown attempt with a PaymentIntent" do
    attempt.update!(status: "unknown")
    allow(Pay::Payment).to receive(:from_id).and_return(Pay::Payment.new(intent(status: "processing")))
    allow(Stripe::PaymentIntent).to receive(:cancel).and_return(intent(status: "canceled"))

    result = described_class.call(attempt:)

    expect(result).to be_success
    expect(attempt.reload).to have_attributes(status: "failed", error_code: "canceled_by_admin")
  end

  it "refuses a resolved attempt" do
    attempt.update!(status: "failed")
    allow(Stripe::PaymentIntent).to receive(:cancel)

    result = described_class.call(attempt:)

    expect(result).not_to be_success
    expect(Stripe::PaymentIntent).not_to have_received(:cancel)
  end

  it "refuses an attempt with no PaymentIntent" do
    attempt.update!(status: "unknown", payment_intent_id: nil)

    result = described_class.call(attempt:)

    expect(result).not_to be_success
    expect(result.errors).to include(/no PaymentIntent/)
  end

  it "reconciles instead of canceling when Stripe says it already succeeded" do
    allow(Pay::Payment).to receive(:from_id).and_return(Pay::Payment.new(intent(status: "succeeded")))
    allow(Stripe::PaymentIntent).to receive(:cancel)
    allow(Membership::Reconcile).to receive(:call) do
      attempt.update!(status: "succeeded")
      Membership::Reconcile::Result.new(status: :succeeded, attempt:, payment: nil,
        message: "Reconciled.", errors: [])
    end

    result = described_class.call(attempt:)

    expect(result).to be_success
    expect(Stripe::PaymentIntent).not_to have_received(:cancel)
  end
end
