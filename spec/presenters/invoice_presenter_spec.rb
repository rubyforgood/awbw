require "rails_helper"

RSpec.describe InvoicePresenter do
  let(:person) { create(:person, first_name: "Jane", last_name: "Doe") }
  let(:invoice) { create(:invoice, bill_to_address: "123 Main St\nLos Angeles, CA 90001", attention_person: person, invoicee: person) }
  let(:presenter) { described_class.new(invoice) }

  describe "#bill_to_name" do
    it "returns the invoicee name" do
      expect(presenter.bill_to_name).to eq("Jane Doe")
    end
  end

  describe "#bill_to_address_lines" do
    it "returns address lines" do
      expect(presenter.bill_to_address_lines).to eq([ "123 Main St", "Los Angeles, CA 90001" ])
    end
  end

  describe "#attention" do
    it "returns the attention person name" do
      expect(presenter.attention).to eq("Jane Doe")
    end
  end

  describe "#total_cents" do
    it "returns the total" do
      item = create(:invoice_line_item, invoice: invoice, unit_price_cents: 10_000, quantity: 2)
      expect(presenter.total_cents).to eq(20_000)
    end
  end

  describe "#issuer_name" do
    it "returns the issuer name" do
      expect(presenter.issuer_name).to eq("A Window Between Worlds")
    end
  end
end
