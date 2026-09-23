require "rails_helper"

RSpec.describe "Invoices", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /invoices" do
    it "returns success" do
      create(:invoice)
      get invoices_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /invoices/new" do
    it "returns success" do
      get new_invoice_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /invoices" do
    context "with valid params" do
      it "creates an invoice" do
        person = create(:person)
        post invoices_path, params: {
          invoice: {
            client_id: person.id,
            client_type: "Person",
            bill_to_address: "123 Main St\nLos Angeles, CA 90001",
            date: Date.current,
            number: "INV-001"
          }
        }
        expect(response).to redirect_to(invoice_path(Invoice.last))
      end
    end

    context "with invalid params" do
      it "does not create an invoice" do
        expect {
          post invoices_path, params: { invoice: { bill_to_address: "" } }
        }.not_to change(Invoice, :count)
      end
    end
  end

  describe "GET /invoices/:id" do
    it "returns success" do
      invoice = create(:invoice, :with_line_items)
      get invoice_path(invoice)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /invoices/:id/edit" do
    it "returns success" do
      invoice = create(:invoice)
      get edit_invoice_path(invoice)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /invoices/:id" do
    it "updates the invoice" do
      invoice = create(:invoice)
      patch invoice_path(invoice), params: {
        invoice: { bill_to_address: "456 Updated St" }
      }
      expect(response).to redirect_to(invoice_path(invoice))
      expect(invoice.reload.bill_to_address).to eq("456 Updated St")
    end
  end

  describe "DELETE /invoices/:id" do
    it "destroys the invoice" do
      invoice = create(:invoice)
      expect {
        delete invoice_path(invoice)
      }.to change(Invoice, :count).by(-1)
      expect(response).to redirect_to(invoices_path)
    end
  end
end
