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

    it "requires a unique number" do
      create(:invoice)
      invoice = build(:invoice, number: Invoice.first.number)
      expect(invoice).not_to be_valid
    end

    it "validates invoicee_type is required" do
      invoice = build(:invoice, invoicee_type: "")
      expect(invoice).not_to be_valid
    end
  end
end
