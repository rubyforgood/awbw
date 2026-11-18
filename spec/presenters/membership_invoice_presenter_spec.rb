require "rails_helper"

RSpec.describe MembershipInvoicePresenter do
  let(:person) { create(:person, :without_user, first_name: "Ada", last_name: "Lovelace") }
  let(:membership) { create(:membership, person: person) }
  let(:invoice) do
    create(:membership_invoice, membership: membership, cost_cents: 25_000,
      start_date: Date.new(2027, 3, 1), end_date: Date.new(2028, 2, 29))
  end
  let(:presenter) { described_class.new(invoice) }

  it "names the period the invoice pays for on the line item" do
    expect(presenter.line_items.first.description)
      .to eq("AWBW annual membership\nMar 1, 2027 – Feb 29, 2028")
  end

  it "omits the member's organization when the member's name is hidden" do
    invoice.update!(organization: create(:organization, name: "Acme Family Services"), hide_invoicee: true)

    expect(presenter.organization_name).to be_nil
  end
end
