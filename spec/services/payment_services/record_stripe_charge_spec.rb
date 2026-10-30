require "rails_helper"

RSpec.describe PaymentServices::RecordStripeCharge do
  let(:person) { create(:person) }
  let(:charge) do
    Stripe::Charge.construct_from(id: "ch_test", object: "charge", amount: 1_000,
      currency: "usd", metadata: { "membership_invoice_id" => 42 })
  end

  it "creates a local payment from the charge" do
    payment = described_class.call(charge:, person:, external_origin: false)

    expect(payment).to be_persisted
    expect(payment).to have_attributes(
      stripe_charge_id: "ch_test",
      person:,
      amount_cents: 1_000,
      amount_cents_remaining: 1_000,
      currency: "usd",
      external_origin: false
    )
    expect(payment.metadata["stripe_charge"]).to be_a(Hash)
  end

  it "reuses an existing payment for the same charge" do
    described_class.call(charge:, person:)

    expect { described_class.call(charge:, person:) }.not_to change(ExternalProcessorPayment, :count)
  end

  it "accepts explicit metadata" do
    payment = described_class.call(charge:, person:, metadata: { "membership_invoice_id" => 42 })

    expect(payment.metadata).to include("membership_invoice_id" => 42)
  end
end
