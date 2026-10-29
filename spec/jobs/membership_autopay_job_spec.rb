require "rails_helper"

RSpec.describe MembershipAutopayJob, type: :job do
  it "only attempts invoices for memberships with autopay on" do
    autopay_invoice = invoice_for(autopay_on: true)
    manual_invoice = invoice_for(autopay_on: false)

    described_class.perform_now

    expect(autopay_invoice.charge_attempts.where(status: "needs_card")).to exist
    expect(manual_invoice.charge_attempts).to be_empty
  end

  it "attempts an invoice issued before its start date" do
    invoice = invoice_for(autopay_on: true, start_date: Date.current + 1.day)

    described_class.perform_now

    expect(invoice.charge_attempts.where(status: "needs_card")).to exist
  end

  it "does not attempt an invoice outside the renewal window" do
    invoice = invoice_for(autopay_on: true,
      start_date: Date.current + Membership.renewal_window_days + 1.day)

    described_class.perform_now

    expect(invoice.charge_attempts).to be_empty
  end

  it "retries a needs-card attempt after a card is added" do
    invoice = invoice_for(autopay_on: true)
    invoice.charge_attempts.create!(
      attempt_number: 1, status: "needs_card", amount_cents: invoice.remaining_cost,
      attempted_at: Time.current, error_code: "no_card"
    )
    add_card(invoice.person)
    allow(Membership::Autopay::Charge).to receive(:call)

    described_class.perform_now

    expect(Membership::Autopay::Charge).to have_received(:call).with(invoice:)
  end

  def add_card(person)
    customer = Pay::Stripe::Customer.create!(owner: person, processor: "stripe",
      processor_id: "cus_test_#{SecureRandom.hex(4)}", default: true)
    Pay::Stripe::PaymentMethod.create!(customer: customer,
      processor_id: "pm_test_#{SecureRandom.hex(4)}",
      payment_method_type: "card",
      data: { "brand" => "visa", "last4" => "4242" })
  end

  def invoice_for(autopay_on:, start_date: Date.current)
    membership = create(:membership, autopay_on: autopay_on, start_date: start_date,
      end_date: start_date + 1.year - 1.day)
    create(:membership_invoice, membership: membership, start_date: start_date,
      end_date: start_date + 1.year - 1.day, cost_cents: 10_000)
  end
end
