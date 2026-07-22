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

      it "renders the blank template as a fillable form with a names/notes area" do
        get event_invoice_path(event)

        expect(response.body).to include("data-controller=\"invoice-editor\"")
        expect(response.body).to include("data-invoice-editor-target=\"quantity\"")
        expect(response.body).to include("data-invoice-editor-target=\"unitPrice\"")
        expect(response.body).to include("Names included in registration fees")
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

      it "is denied the blank template and redirected" do
        get event_invoice_path(event)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /events/:event_id/invoice" do
    context "as an admin" do
      before { sign_in admin }

      let(:invoice_params) do
        {
          invoice: {
            attention: "Jordan Rivera",
            names: "Ada Lovelace\nGrace Hopper",
            line_item: { quantity: "2", unit_price: "1500" }
          }
        }
      end

      it "tracks a generate.invoice Ahoy event tied to the event with the entered details" do
        expect(Analytics::AhoyTracker).to receive(:track_event).with(
          anything,
          "generate.invoice",
          hash_including(
            "resource_type" => "Event",
            "resource_id" => event.id,
            "attention" => "Jordan Rivera",
            "names" => "Ada Lovelace\nGrace Hopper"
          )
        )

        post event_invoice_path(event), params: invoice_params
      end

      it "re-renders the filled-in form so the values survive the save" do
        post event_invoice_path(event), params: invoice_params

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Invoice recorded.")
        expect(response.body).to include("Jordan Rivera")
        expect(response.body).to include("Ada Lovelace")
      end
    end

    context "as a non-admin" do
      before { sign_in create(:user) }

      it "is denied and tracks nothing" do
        expect(Analytics::AhoyTracker).not_to receive(:track_event)

        post event_invoice_path(event), params: { invoice: { attention: "x" } }
        expect(response).to redirect_to(root_path)
      end
    end

    context "as a guest (no account)" do
      let(:form) { create(:form) }
      let!(:submission) { create(:form_submission, form: form, event: event, role: "bulk_payment") }

      it "can view a bulk-payment submission's invoice (matches the public show page)" do
        get event_invoice_path(event, submission_id: submission.id)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("INVOICE")
      end

      it "is denied an invoice for a non-bulk submission" do
        other = create(:form_submission, form: form, event: event, role: "registration")
        get event_invoice_path(event, submission_id: other.id)
        expect(response).to redirect_to(root_path)
      end

      it "is still denied the blank template" do
        get event_invoice_path(event)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
