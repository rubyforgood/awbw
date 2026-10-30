require "rails_helper"

RSpec.describe MembershipInvoiceReconciliation do
  let(:invoice) { create(:membership_invoice, cost_cents: 1_000) }

  it "summarizes an unresolved attempt and a stale checkout" do
    invoice.charge_attempts.create!(attempt_number: 1, status: "unknown",
      amount_cents: 1_000, attempted_at: 1.hour.ago)
    invoice.update_columns(checkout_session_id: "cs_test", payment_in_progress_at: 2.hours.ago)

    summary = described_class.new(invoice)

    expect(summary).to be_needed
    expect(summary.issues.map(&:kind)).to contain_exactly(:unresolved_attempt, :stale_checkout)
    expect(summary.summary).to include("1 unresolved attempt")
    expect(summary.summary).to include("checkout session")
    expect(summary.path(return_to: "membership")).to eq(
      Rails.application.routes.url_helpers.membership_invoice_reconciliation_path(
        invoice, return_to: "membership"
      )
    )
  end

  it "reports nothing for a clean invoice" do
    expect(described_class.new(invoice)).not_to be_needed
  end
end
