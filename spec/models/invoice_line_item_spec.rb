require "rails_helper"

RSpec.describe InvoiceLineItem do
  describe "#amount_cents" do
    it "computes quantity times unit_price_cents" do
      item = build(:invoice_line_item, unit_price_cents: 10_000, quantity: 3)
      expect(item.amount_cents).to eq(30_000)
    end
  end

  describe "validations" do
    it "is valid with required fields" do
      item = build(:invoice_line_item)
      expect(item).to be_valid
    end

    it "requires quantity >= 1" do
      item = build(:invoice_line_item, quantity: 0)
      expect(item).not_to be_valid
    end
  end
end
