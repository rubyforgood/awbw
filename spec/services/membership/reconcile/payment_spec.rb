require "rails_helper"

RSpec.describe Membership::Reconcile::Payment do
  let(:person) { create(:person) }
  let(:membership) { create(:membership, person:) }
  let(:invoice) { create(:membership_invoice, membership:, cost_cents: 1_000) }
  let(:payment) do
    create(:external_processor_payment, person:, amount_cents: 1_000, amount_cents_remaining: 1_000)
  end

  it "applies the payment to the invoice" do
    result = described_class.call(invoice:, payment:)

    expect(result).to be_success
    expect(result.status).to eq(:applied)
    expect(result.amount_cents).to eq(1_000)
    expect(invoice.reload).to be_paid_in_full
    expect(payment.reload.amount_cents_remaining).to eq(0)
  end

  it "applies only what the invoice still owes" do
    create(:allocation, source: create(:payment, person:, amount_cents: 400), allocatable: invoice, amount: 400)

    result = described_class.call(invoice:, payment:)

    expect(result.amount_cents).to eq(600)
    expect(invoice.reload).to be_paid_in_full
    expect(payment.reload.amount_cents_remaining).to eq(400)
  end

  it "applies the remaining amount after a partial allocation" do
    create(:allocation, source: payment, allocatable: invoice, amount: 400)

    result = described_class.call(invoice:, payment:)

    expect(result.status).to eq(:applied)
    expect(result.amount_cents).to eq(600)
    expect(invoice.reload).to be_paid_in_full
    expect(payment.reload.amount_cents_remaining).to eq(0)
  end

  it "applies the remaining amount after an allocation was reverted" do
    original = create(:allocation, source: payment, allocatable: invoice, amount: 1_000)
    revert = create(:allocation, source: payment, allocatable: invoice, amount: -1_000)
    original.update!(reverted_id: revert.id)

    result = described_class.call(invoice:, payment:)

    expect(result.status).to eq(:applied)
    expect(result.amount_cents).to eq(1_000)
    expect(invoice.reload).to be_paid_in_full
    expect(payment.reload.amount_cents_remaining).to eq(0)
  end

  it "is idempotent when the payment is already applied" do
    create(:allocation, source: payment, allocatable: invoice, amount: 1_000)

    result = described_class.call(invoice:, payment:)

    expect(result.status).to eq(:already_applied)
    expect(invoice.allocations.count).to eq(1)
  end

  it "leaves the payment unallocated when another payment settled the invoice" do
    create(:allocation, source: create(:payment, person:, amount_cents: 1_000), allocatable: invoice, amount: 1_000)

    result = described_class.call(invoice:, payment:)

    expect(result.status).to eq(:invoice_paid)
    expect(result).to be_success
    expect(payment.reload.amount_cents_remaining).to eq(1_000)
  end

  it "resolves the linked attempt and clears the reconciliation worklist" do
    customer = Pay::Stripe::Customer.create!(owner: person, processor: "stripe",
      processor_id: "cus_test", default: true)
    charge = Pay::Charge.create!(
      customer:, processor_id: "ch_test", amount: 1_000, amount_refunded: 0,
      currency: "usd", metadata: {},
      object: { "paid" => false, "refunds" => { "object" => "list", "data" => [] } }
    )
    attempt = invoice.charge_attempts.create!(
      attempt_number: 1, status: "unknown", amount_cents: 1_000, attempted_at: 1.hour.ago,
      pay_charge: charge, error_code: "allocation_failed", error_message: "Not applied."
    )
    linked_payment = create(:external_processor_payment, person:, amount_cents: 1_000,
      amount_cents_remaining: 1_000, stripe_charge_id: "ch_test", pay_charge: charge)

    expect(MembershipInvoice.needing_reconciliation).to include(invoice)

    result = described_class.call(invoice:, payment: linked_payment)

    expect(result).to be_success
    expect(attempt.reload).to have_attributes(status: "succeeded", error_code: nil, error_message: nil)
    expect(MembershipInvoice.needing_reconciliation).not_to include(invoice)
  end
end
