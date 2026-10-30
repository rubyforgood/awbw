require "rails_helper"

RSpec.describe Membership::Reconcile::Lookup do
  let(:person) { create(:person) }
  let(:membership) { create(:membership, person:) }
  let(:invoice) { create(:membership_invoice, membership:, cost_cents: 1_000) }
  let!(:customer) do
    Pay::Stripe::Customer.create!(owner: person, processor: "stripe",
      processor_id: "cus_test", default: true)
  end

  def intent(metadata: { "membership_invoice_id" => invoice.id.to_s, "attempt_number" => "1" })
    Stripe::PaymentIntent.construct_from(
      id: "pi_test", object: "payment_intent", status: "succeeded", amount: 1_000,
      currency: "usd", created: Time.current.to_i, latest_charge: "ch_test",
      customer: customer.processor_id, metadata:
    )
  end

  it "maps a Stripe intent to the attempt and local payment" do
    attempt = invoice.charge_attempts.create!(attempt_number: 1, status: "pending",
      amount_cents: 1_000, attempted_at: 1.hour.ago)
    payment = create(:external_processor_payment, person:, amount_cents: 1_000,
      amount_cents_remaining: 1_000, stripe_charge_id: "ch_test")
    allow(Stripe::PaymentIntent).to receive(:list).and_return(double(data: [ intent ]))

    result = described_class.call(invoice:)

    expect(result).to be_success
    candidate = result.candidates.first
    expect(candidate.payment_intent_id).to eq("pi_test")
    expect(candidate.attempt).to eq(attempt)
    expect(candidate.payment).to eq(payment)
    expect(candidate.can_link_attempt?).to be(true)
    expect(candidate.can_apply?).to be(true)
  end

  it "ignores intents for other invoices" do
    allow(Stripe::PaymentIntent).to receive(:list).and_return(double(data: [ intent(metadata: {}) ]))

    result = described_class.call(invoice:)

    expect(result).to be_success
    expect(result.candidates).to be_empty
  end
end
