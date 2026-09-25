require "rails_helper"

RSpec.describe Invoice do
  describe "#total_cents" do
    it "sums line item amounts" do
      invoice = create(:invoice)
      create(:invoice_line_item, invoice: invoice, unit_price_cents: 10_000, quantity: 2)
      create(:invoice_line_item, invoice: invoice, unit_price_cents: 5_000, quantity: 1)

      expect(invoice.total_cents).to eq(25_000)
    end
  end

  describe "validations" do
    it "is valid with required fields" do
      invoice = build(:invoice)
      expect(invoice).to be_valid
    end

    it "does not require an address or additional info" do
      invoice = build(:invoice, bill_to_address: nil, bill_to_additional_info: nil)
      expect(invoice).to be_valid
    end

    it "requires a unique number" do
      create(:invoice)
      invoice = build(:invoice, number: Invoice.first.number)
      expect(invoice).not_to be_valid
    end

    it "validates invoicee_type is required" do
      invoice = build(:invoice, invoicee_type: "")
      expect(invoice).not_to be_valid
    end

    it "accepts one of the invoicee's addresses" do
      person = create(:person)
      address = create(:address, addressable: person)

      expect(build(:invoice, invoicee: person, bill_to_address: address)).to be_valid
    end

    it "rejects an address belonging to someone else" do
      invoicee = create(:person)
      address = create(:address, addressable: create(:organization))

      invoice = build(:invoice, invoicee: invoicee, bill_to_address: address)

      expect(invoice).not_to be_valid
      expect(invoice.errors[:bill_to_address]).to include("must be one of the invoicee's addresses")
    end

    it "rejects an address left over from a previous invoicee" do
      person = create(:person)
      address = create(:address, addressable: person)
      invoice = build(:invoice, invoicee: person, bill_to_address: address)
      invoice.invoicee = create(:person)

      expect(invoice).not_to be_valid
    end
  end
end
