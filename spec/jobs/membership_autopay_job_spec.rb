require "rails_helper"

RSpec.describe MembershipAutopayJob, type: :job do
  it "only attempts invoices for memberships with autopay on" do
    autopay_invoice = invoice_for(autopay_on: true)
    manual_invoice = invoice_for(autopay_on: false)

    described_class.perform_now

    expect(autopay_invoice.charge_attempts.where(status: "needs_card")).to exist
    expect(manual_invoice.charge_attempts).to be_empty
  end

  it "only attempts invoices for the given membership" do
    targeted_invoice = invoice_for(autopay_on: true)
    other_invoice = invoice_for(autopay_on: true)

    described_class.perform_now(targeted_invoice.membership_id)

    expect(targeted_invoice.charge_attempts.where(status: "needs_card")).to exist
    expect(other_invoice.charge_attempts).to be_empty
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

  def invoice_for(autopay_on:, start_date: Date.current)
    membership = create(:membership, autopay_on: autopay_on, start_date: start_date,
      end_date: start_date + 1.year - 1.day)
    create(:membership_invoice, membership: membership, start_date: start_date,
      end_date: start_date + 1.year - 1.day, cost_cents: 10_000)
  end
end
