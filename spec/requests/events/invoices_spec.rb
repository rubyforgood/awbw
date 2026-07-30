require "rails_helper"

RSpec.describe "Events::Invoices", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, title: "AWBW 2-Day Art Facilitator Training", cost_cents: 150_000) }

  # Only the admin blank template lives here now; a bulk-payment submission's
  # invoice is served by Events::BulkPaymentFormSubmissions#invoice (slug-based).
  describe "GET /events/:event_id/invoice" do
    context "as an admin" do
      before { sign_in admin }

      it "renders a blank invoice template carrying the event's content" do
        get event_invoice_path(event)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("INVOICE")
        expect(response.body).to include("AWBW 2-Day Art Facilitator Training")
        expect(response.body).to include("$1,500")
      end
    end

    context "as a non-admin" do
      before { sign_in create(:user) }

      it "is denied the blank template and redirected" do
        get event_invoice_path(event)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as a guest (no account)" do
      it "is denied the blank template and redirected" do
        get event_invoice_path(event)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
