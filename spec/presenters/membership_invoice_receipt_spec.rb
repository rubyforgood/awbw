require "rails_helper"

RSpec.describe MembershipInvoiceReceipt do
  let(:person) { create(:person, :without_user, first_name: "Ada", last_name: "Lovelace") }
  let!(:address) { create(:address, addressable: person, street_address: "1 Main St", city: "Los Angeles", state: "CA", zip_code: "90001") }
  let(:membership) { create(:membership, person: person) }
  let(:invoice) { create(:membership_invoice, membership: membership, cost_cents: 25_000) }
  let(:receipt) { described_class.new(invoice) }

  it "bills the member by default and reconciles a single payment" do
    create(:allocation, source: create(:payment, amount_cents: 25_000), allocatable: invoice, amount: 25_000)

    expect(receipt.number).to eq("MR-#{invoice.id}")
    expect(receipt.date).to eq(invoice.allocations.last.created_at.to_date)
    expect(receipt.client_id).to eq(person.id)
    expect(receipt.bill_to_name).to eq("Ada Lovelace")
    expect(receipt.bill_to_address_lines).to eq([ "1 Main St", "Los Angeles, CA 90001" ])
    expect(receipt.attention).to be_nil
    expect(receipt.line_items.map(&:amount_cents)).to eq([ 25_000 ])
    expect(receipt.total_cents).to eq(25_000)
    expect(receipt.amount_paid_cents).to eq(25_000)
    expect(receipt.balance_cents).to eq(0)
    expect(receipt).to be_paid_in_full
    expect(receipt.entries.map(&:method)).to eq([ "Cash" ])
  end

  it "follows the invoice's bill-to overrides and lists payments and credits" do
    organization = create(:organization, name: "Acme Family Services")
    invoice.update!(invoicee: organization, hide_address: true, bill_to_additional_info: "Attn: Accounts Payable")
    create(:allocation, source: create(:payment, type: "CheckPayment", amount_cents: 20_000, check_number: "4821"),
      allocatable: invoice, amount: 20_000)
    create(:allocation, source: create(:discount, amount_cents: 5_000), allocatable: invoice, amount: 5_000)

    expect(receipt.bill_to_name).to eq("Acme Family Services")
    expect(receipt.bill_to_address_lines).to eq([])
    expect(receipt.additional_info).to eq("Attn: Accounts Payable")
    expect(receipt.entries.map(&:method)).to eq([ "Check", "Discount" ])
    expect(receipt.entries.first.reference).to eq("Check #4821")
    expect(receipt.amount_paid_cents).to eq(25_000)
    expect(receipt.balance_cents).to eq(0)
  end
end
