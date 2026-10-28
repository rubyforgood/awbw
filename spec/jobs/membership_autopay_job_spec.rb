require "rails_helper"

RSpec.describe MembershipAutopayJob, type: :job do
  it "only attempts invoices for memberships with autopay on" do
    autopay_invoice = invoice_for(autopay_on: true)
    manual_invoice = invoice_for(autopay_on: false)

    described_class.perform_now

    expect(autopay_invoice.charge_attempts.where(status: "needs_card")).to exist
    expect(manual_invoice.charge_attempts).to be_empty
  end

  def invoice_for(autopay_on:)
    membership = create(:membership, autopay_on: autopay_on)
    create(:membership_invoice, membership: membership, start_date: Date.current,
      end_date: Date.current + 1.year - 1.day, cost_cents: 10_000)
  end
end
