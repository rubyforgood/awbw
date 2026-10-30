require "rails_helper"

RSpec.describe Membership::Reconcile::Charge do
  let(:person) { create(:person, :without_user) }
  let(:membership) { create(:membership, person:) }
  let(:invoice) { create(:membership_invoice, membership:, cost_cents: 1_000) }
  let!(:customer) do
    Pay::Stripe::Customer.create!(owner: person, processor: "stripe",
      processor_id: "cus_test", default: true)
  end
  let(:pay_charge) do
    create(:pay_charge, customer:, processor_id: "ch_test", amount: 1_000)
  end
  let(:intent) do
    Stripe::PaymentIntent.construct_from(
      id: "pi_test", object: "payment_intent", status: "succeeded", amount: 1_000,
      currency: "usd", customer: customer.processor_id, latest_charge: "ch_test",
      metadata: { "membership_invoice_id" => invoice.id.to_s }
    )
  end

  it "syncs the charge and applies the local payment" do
    create(:external_processor_payment, person:, amount_cents: 1_000, amount_cents_remaining: 1_000,
      stripe_charge_id: "ch_test", pay_charge:)
    attempt = invoice.charge_attempts.create!(attempt_number: 1, status: "pending",
      amount_cents: 1_000, attempted_at: 1.hour.ago, payment_intent_id: "pi_test")
    allow(Pay::Stripe::Charge).to receive(:sync_payment_intent).and_return(pay_charge)

    result = described_class.call(invoice:, intent:, attempt:)

    expect(result).to be_success
    expect(result).to be_allocated
    expect(invoice.reload).to be_paid_in_full
    expect(attempt.reload).to have_attributes(status: "succeeded", pay_charge:)
  end

  it "applies an existing local payment when Pay sync fails" do
    create(:external_processor_payment, person:, amount_cents: 1_000, amount_cents_remaining: 1_000,
      stripe_charge_id: "ch_test", pay_charge:)
    allow(Pay::Stripe::Charge).to receive(:sync_payment_intent)
      .and_raise(Stripe::APIConnectionError.new("Pay is down"))

    result = described_class.call(invoice:, intent:)

    expect(result).to be_success
    expect(result).to be_allocated
    expect(invoice.reload).to be_paid_in_full
  end

  it "reports when Pay syncs the charge but no local payment exists" do
    allow(Pay::Stripe::Charge).to receive(:sync_payment_intent).and_return(pay_charge)

    result = described_class.call(invoice:, intent:)

    expect(result).not_to be_success
    expect(result.errors).to include(/no local payment/)
  end

  it "refuses an intent that belongs to another customer" do
    other = Stripe::PaymentIntent.construct_from(
      id: "pi_other", object: "payment_intent", status: "succeeded", amount: 1_000,
      currency: "usd", customer: "cus_other", metadata: {}
    )
    allow(Pay::Stripe::Charge).to receive(:sync_payment_intent)

    result = described_class.call(invoice:, intent: other)

    expect(result).not_to be_success
    expect(Pay::Stripe::Charge).not_to have_received(:sync_payment_intent)
  end
end
