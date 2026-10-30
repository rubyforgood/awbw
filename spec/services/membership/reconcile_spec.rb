require "rails_helper"

RSpec.describe Membership::Reconcile do
  let(:person) { create(:person) }
  let(:membership) { create(:membership, person:) }
  let(:invoice) { create(:membership_invoice, membership:, cost_cents: 1_000) }
  let!(:customer) do
    Pay::Stripe::Customer.create!(owner: person, processor: "stripe",
      processor_id: "cus_test", default: true)
  end
  let(:attempt) do
    invoice.charge_attempts.create!(attempt_number: 1, status: "unknown",
      amount_cents: 1_000, attempted_at: 1.hour.ago, payment_intent_id: "pi_test")
  end

  def intent(status:)
    Stripe::PaymentIntent.construct_from(
      id: "pi_test", object: "payment_intent", status:, amount: 1_000,
      currency: "usd", customer: customer.processor_id,
      metadata: { "membership_invoice_id" => invoice.id.to_s }
    )
  end

  it "applies a succeeded charge and marks the attempt succeeded" do
    pay_charge = create(:pay_charge, customer:, processor_id: "ch_test", amount: 1_000)
    create(:external_processor_payment, person:, amount_cents: 1_000, amount_cents_remaining: 1_000,
      stripe_charge_id: "ch_test", pay_charge:)
    allow(Pay::Payment).to receive(:from_id).and_return(Pay::Payment.new(intent(status: "succeeded")))
    allow(Pay::Stripe::Charge).to receive(:sync_payment_intent).and_return(pay_charge)

    result = described_class.call(attempt:)

    expect(result).to be_success
    expect(attempt.reload).to have_attributes(status: "succeeded", pay_charge:)
    expect(invoice.reload).to be_paid_in_full
  end

  it "records a card that still needs authentication" do
    allow(Pay::Payment).to receive(:from_id).and_return(Pay::Payment.new(intent(status: "requires_action")))

    result = described_class.call(attempt:)

    expect(result).to be_success
    expect(attempt.reload).to be_needs_action
  end

  it "asks for a Stripe lookup when no PaymentIntent was stored" do
    attempt.update!(payment_intent_id: nil, status: "pending")

    result = described_class.call(attempt:)

    expect(result).not_to be_success
    expect(result.errors).to include(/No PaymentIntent is stored/)
  end
end
