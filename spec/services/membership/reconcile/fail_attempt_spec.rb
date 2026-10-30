require "rails_helper"

RSpec.describe Membership::Reconcile::FailAttempt do
  let(:person) { create(:person) }
  let(:membership) { create(:membership, person:) }
  let(:invoice) { create(:membership_invoice, membership:, cost_cents: 1_000) }

  it "marks a no-intent attempt failed so autopay can retry" do
    attempt = invoice.charge_attempts.create!(attempt_number: 1, status: "pending",
      amount_cents: 1_000, attempted_at: 1.hour.ago)

    result = described_class.call(attempt:)

    expect(result).to be_success
    expect(attempt.reload).to have_attributes(
      status: "failed", error_code: "manually_resolved",
      next_attempt_on: Date.current + 1.day
    )
  end

  it "refuses an attempt whose PaymentIntent Stripe still owns" do
    attempt = invoice.charge_attempts.create!(attempt_number: 1, status: "needs_action",
      amount_cents: 1_000, attempted_at: 1.hour.ago, payment_intent_id: "pi_test")

    result = described_class.call(attempt:)

    expect(result).not_to be_success
    expect(attempt.reload).to be_needs_action
  end
end
