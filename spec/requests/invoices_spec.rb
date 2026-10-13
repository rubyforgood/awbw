require "rails_helper"

RSpec.describe "Invoices", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  let(:invoicee) { create(:person, first_name: "Jane", last_name: "Doe") }
  let(:address) { create(:address, addressable: invoicee, street_address: "123 Main St", city: "Los Angeles", state: "CA", zip_code: "90001") }

  def invoice_params(overrides = {})
    {
      number: "INV-001",
      date: Date.current,
      invoicee_sgid: invoicee.to_sgid.to_s,
      bill_to_address_id: address.id,
      bill_to_additional_info: "Suite 200",
      invoice_line_items_attributes: { "0" => { description: "Training", quantity: 1, unit_price_dollars: "100.00" } }
    }.merge(overrides)
  end

  describe "POST /invoices" do
    it "creates an invoice linked to the invoicee and one of its addresses" do
      expect {
        post invoices_path, params: { invoice: invoice_params }
      }.to change(Invoice, :count).by(1)

      invoice = Invoice.find_by(number: "INV-001")
      expect(invoice.invoicee).to eq(invoicee)
      expect(invoice.bill_to_address).to eq(address)
      expect(invoice.bill_to_additional_info).to eq("Suite 200")
      expect(response).to redirect_to(invoice_path(invoice))
    end

    it "saves the display toggles" do
      post invoices_path, params: { invoice: invoice_params(hide_invoicee: "1", hide_address: "1") }

      invoice = Invoice.find_by(number: "INV-001")
      expect(invoice.hide_invoicee).to be(true)
      expect(invoice.hide_address).to be(true)
    end

    it "saves without an address or additional info" do
      post invoices_path, params: { invoice: invoice_params(bill_to_address_id: "", bill_to_additional_info: "") }

      invoice = Invoice.find_by(number: "INV-001")
      expect(invoice.bill_to_address).to be_nil
      expect(invoice.bill_to_additional_info).to be_blank
    end

    it "rejects an address belonging to someone else" do
      other_address = create(:address, addressable: create(:organization))

      expect {
        post invoices_path, params: { invoice: invoice_params(bill_to_address_id: other_address.id) }
      }.not_to change(Invoice, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "still requires an invoicee" do
      expect {
        post invoices_path, params: { invoice: invoice_params(invoicee_sgid: "") }
      }.not_to change(Invoice, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /invoices/:id" do
    let!(:invoice) { create(:invoice, invoicee: invoicee, bill_to_address: address) }

    it "updates the address, additional info, and toggles" do
      other_address = create(:address, addressable: invoicee, street_address: "PO Box 5")

      patch invoice_path(invoice), params: {
        invoice: {
          bill_to_address_id: other_address.id,
          bill_to_additional_info: "Attn: Front Desk",
          hide_invoicee: "1"
        }
      }

      invoice.reload
      expect(invoice.bill_to_address).to eq(other_address)
      expect(invoice.bill_to_additional_info).to eq("Attn: Front Desk")
      expect(invoice.hide_invoicee).to be(true)
      expect(invoice.hide_address).to be(false)
    end
  end

  describe "authorization" do
    it "is not available to a signed-out visitor" do
      sign_out admin
      get invoices_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "is not available to a non-admin" do
      sign_in create(:user)
      get invoices_path
      expect(response).to redirect_to(root_path)
    end
  end
end
