require "rails_helper"

RSpec.describe "Events::Invoices", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, title: "AWBW 2-Day Art Facilitator Training", cost_cents: 150_000) }

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

      context "with a submission_id" do
        let(:form) { create(:form) }
        let(:payer) { create(:person) }
        let!(:submission) { create(:form_submission, person: payer, form: form, event: event, role: "bulk_payment") }

        def add_answer(identifier, value)
          field = create(:form_field, form: form, field_identifier: identifier, name: identifier.humanize)
          create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
        end

        before do
          add_answer("payer_first_name", "Helena")
          add_answer("payer_last_name", "Lopez")
          add_answer("payer_organization", "A Greater Hope")
          add_answer("number_of_attendees", "8")
        end

        it "autofills the invoice from the bulk-payment submission" do
          get event_invoice_path(event, submission_id: submission.id)

          expect(response).to have_http_status(:success)
          expect(response.body).to include("A Greater Hope")
          expect(response.body).to include("Helena Lopez")
          # 8 attendees × $1,500 = $12,000
          expect(response.body).to include("$12,000")
        end
      end
    end

    context "as a non-admin" do
      before { sign_in create(:user) }

      it "is denied and redirected" do
        get event_invoice_path(event)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
