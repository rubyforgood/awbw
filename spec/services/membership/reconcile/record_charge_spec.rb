require "rails_helper"

RSpec.describe Membership::Reconcile::RecordCharge do
  let(:person) { create(:person) }
  let(:membership) { create(:membership, person:) }
  let(:invoice) { create(:membership_invoice, membership:, cost_cents: 1_000) }
  let(:charge) do
    Stripe::Charge.construct_from(id: "ch_record", object: "charge", amount: 1_000,
      currency: "usd", metadata: {})
  end
  let(:intent) { intent_for }
  let(:attempt) do
    invoice.charge_attempts.create!(attempt_number: 1, status: "unknown",
      amount_cents: 1_000, attempted_at: 1.hour.ago, payment_intent_id: "pi_record")
  end

  before do
    allow(Pay::Stripe::Charge).to receive(:sync_payment_intent).and_return(nil)
  end

  def intent_for(id: "pi_record", status: "succeeded",
    metadata: { "membership_invoice_id" => invoice.id.to_s },
    customer: "cus_test", latest_charge: charge)
    Stripe::PaymentIntent.construct_from(
      id:, object: "payment_intent", status:, amount: 1_000,
      currency: "usd", customer:, latest_charge:, metadata:
    )
  end

  it "records the charge, applies it, and marks the attempt succeeded" do
    result = described_class.call(invoice:, intent:, attempt:)

    expect(result).to be_success
    payment = ExternalProcessorPayment.find_by!(stripe_charge_id: "ch_record")
    expect(payment).to have_attributes(person:, amount_cents: 1_000, amount_cents_remaining: 0)
    expect(invoice.reload).to be_paid_in_full
    expect(attempt.reload).to be_succeeded
  end

  it "reuses an existing local payment" do
    create(:external_processor_payment, person:, amount_cents: 1_000,
      amount_cents_remaining: 1_000, stripe_charge_id: "ch_record")

    expect { described_class.call(invoice:, intent:, attempt:) }
      .not_to change(ExternalProcessorPayment, :count)
    expect(invoice.reload).to be_paid_in_full
  end

  it "refuses a payment that is not succeeded" do
    result = described_class.call(invoice:, intent: intent_for(status: "requires_action"), attempt:)

    expect(result).not_to be_success
    expect(ExternalProcessorPayment.find_by(stripe_charge_id: "ch_record")).to be_nil
  end

  it "refuses a charge that belongs to another customer" do
    result = described_class.call(
      invoice:,
      intent: intent_for(id: "pi_other", metadata: {}, customer: "cus_other"),
      attempt:
    )

    expect(result).not_to be_success
    expect(ExternalProcessorPayment.find_by(stripe_charge_id: "ch_record")).to be_nil
  end

  it "refuses a succeeded intent with no charge" do
    result = described_class.call(invoice:, intent: intent_for(latest_charge: nil), attempt:)

    expect(result).not_to be_success
    expect(ExternalProcessorPayment.find_by(stripe_charge_id: "ch_record")).to be_nil
  end
end
