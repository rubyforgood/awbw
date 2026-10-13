require "rails_helper"

RSpec.describe InvoicePresenter do
  let(:person) { create(:person, first_name: "Jane", last_name: "Doe") }
  let(:address) { create(:address, addressable: person, street_address: "123 Main St", city: "Los Angeles", state: "CA", zip_code: "90001") }
  let(:invoice) { create(:invoice, attention_person: person, invoicee: person, bill_to_address: address, bill_to_additional_info: "Suite 200") }
  let(:presenter) { described_class.new(invoice) }

  describe "#bill_to_name" do
    it "returns the invoicee name" do
      expect(presenter.bill_to_name).to eq("Jane Doe")
    end

    it "is blank when the invoicee is hidden" do
      invoice.update!(hide_invoicee: true)
      expect(presenter.bill_to_name).to be_nil
    end
  end

  describe "#bill_to_address_lines" do
    it "returns the selected address lines" do
      expect(presenter.bill_to_address_lines).to eq([ "123 Main St", "Los Angeles, CA 90001" ])
    end

    it "is empty when the address is hidden" do
      invoice.update!(hide_address: true)
      expect(presenter.bill_to_address_lines).to eq([])
    end

    it "is empty when no address is selected" do
      invoice.update!(bill_to_address: nil)
      expect(presenter.bill_to_address_lines).to eq([])
    end
  end

  describe "#additional_info" do
    it "returns the free-form info" do
      expect(presenter.additional_info).to eq("Suite 200")
    end

    it "is nil when blank" do
      invoice.update!(bill_to_additional_info: "  ")
      expect(presenter.additional_info).to be_nil
    end
  end

  describe "#show_bill_to?" do
    it "is true when anything is shown" do
      expect(presenter.show_bill_to?).to be(true)
    end

    it "is false when the invoicee and address are hidden with no additional info" do
      invoice.update!(hide_invoicee: true, hide_address: true, bill_to_additional_info: nil)
      expect(presenter.show_bill_to?).to be(false)
    end

    it "is true when only additional info remains" do
      invoice.update!(hide_invoicee: true, hide_address: true, bill_to_additional_info: "Attn: Front Desk")
      expect(presenter.show_bill_to?).to be(true)
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
