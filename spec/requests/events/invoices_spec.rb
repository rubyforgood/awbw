require "rails_helper"

RSpec.describe "Events::Invoices", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, title: "AWBW 2-Day Art Facilitator Training", cost_cents: 150_000) }
  # A real browser User-Agent so Ahoy doesn't skip the request as a bot.
  let(:browser_headers) { { "User-Agent" => "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/120 Safari/537.36" } }

  def recipient_view(submission, time: Time.current)
    create(
      :ahoy_event,
      name: FormSubmission::INVOICE_VIEW_EVENT,
      properties: { resource_type: "FormSubmission", resource_id: submission.id, viewer_role: "recipient" },
      time: time
    )
  end

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

        it "records its own visit as an admin view, not a recipient open" do
          expect { get event_invoice_path(event, submission_id: submission.id), headers: browser_headers }
            .not_to change { submission.invoice_views.count }
        end

        it "shows when the payer first opened it" do
          admin.update!(time_zone: "UTC") # render the timestamp in a known zone
          recipient_view(submission, time: Time.utc(2026, 11, 12, 19, 26))

          get event_invoice_path(event, submission_id: submission.id)

          expect(response.body).to include("First opened Nov 12, 2026 at 7:26 PM")
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

    context "as a guest (no account)" do
      let(:form) { create(:form) }
      let!(:submission) { create(:form_submission, form: form, event: event, role: "bulk_payment") }

      it "can view a bulk-payment submission's invoice (matches the public show page)" do
        get event_invoice_path(event, submission_id: submission.id)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("INVOICE")
      end

      it "records the payer's open as a recipient view" do
        expect { get event_invoice_path(event, submission_id: submission.id), headers: browser_headers }
          .to change { submission.invoice_views.count }.by(1)
      end

      it "does not show the admin-only badge to the payer" do
        recipient_view(submission)

        get event_invoice_path(event, submission_id: submission.id)

        expect(response.body).not_to include("First opened")
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
