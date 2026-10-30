require "rails_helper"

RSpec.describe MembershipPaymentLink do
  let(:person) { create(:person, :without_user) }
  let(:membership) { create(:membership, person:) }
  let(:invoice) { create(:membership_invoice, membership:, cost_cents: 1_000) }

  def payment(metadata: {}, pay_charge: nil)
    create(:external_processor_payment, person:, metadata:, pay_charge:)
  end

  it "links a payment through its autopay attempt" do
    customer = Pay::Stripe::Customer.create!(owner: person, processor: "stripe",
      processor_id: "cus_test", default: true)
    charge = Pay::Charge.create!(
      customer:, processor_id: "ch_test", amount: 1_000, amount_refunded: 0,
      currency: "usd", metadata: {},
      object: { "paid" => false, "refunds" => { "object" => "list", "data" => [] } }
    )
    invoice.charge_attempts.create!(attempt_number: 1, status: "unknown",
      amount_cents: 1_000, attempted_at: 1.hour.ago, pay_charge: charge)

    expect(described_class.invoice_for(payment(pay_charge: charge))).to eq(invoice)
  end

  it "links a payment through top-level metadata" do
    expect(described_class.invoice_for(payment(metadata: { "membership_invoice_id" => invoice.id })))
      .to eq(invoice)
  end

  it "links a payment through nested charge metadata" do
    metadata = { "stripe_charge" => { "metadata" => { "membership_invoice_id" => invoice.id } } }

    expect(described_class.invoice_for(payment(metadata:))).to eq(invoice)
  end

  it "treats a missing invoice as a credit" do
    link = described_class.new(payment(metadata: { "membership_invoice_id" => 999_999 }))

    expect(link.invoice).to be_nil
    expect(link).to be_credit
  end
end
