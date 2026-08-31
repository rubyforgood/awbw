require "rails_helper"

RSpec.describe "BulkPayments", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:frame_headers) { { "Turbo-Frame" => "bulk_payments_results" } }

  describe "GET /bulk_payments" do
    context "as an admin" do
      before { sign_in admin }

      it "renders the filterable index shell" do
        get bulk_payments_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Bulk payment form submissions")
      end

      it "lists only bulk payment submissions" do
        event = create(:event)
        bulk = create(:form_submission, role: "bulk_payment", event: event)
        other = create(:form_submission, role: "registration", event: event)

        get bulk_payments_path, headers: frame_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("form-submission-row-#{bulk.id}")
        expect(response.body).not_to include("form-submission-row-#{other.id}")
      end

      it "links each row to its event's bulk payments page with anchor and highlight" do
        event = create(:event)
        submission = create(:form_submission, role: "bulk_payment", event: event)

        get bulk_payments_path, headers: frame_headers

        expect(response.body).to include(bulk_payments_event_path(event))
        expect(response.body).to include("highlight=#{submission.id}")
        expect(response.body).to include("return_to=bulk_payments_index")
        expect(response.body).to include("#payment-card-#{submission.id}")
      end

      it "filters by search on the payer name" do
        event = create(:event)
        priya = create(:person, first_name: "Priya", last_name: "Patel")
        other = create(:person, first_name: "Sam", last_name: "Jones")
        mine = create(:form_submission, role: "bulk_payment", event: event, person: priya)
        theirs = create(:form_submission, role: "bulk_payment", event: event, person: other)

        get bulk_payments_path(search: "Priya"), headers: frame_headers

        expect(response.body).to include("form-submission-row-#{mine.id}")
        expect(response.body).not_to include("form-submission-row-#{theirs.id}")
      end

      it "finds an account-less payer by a submitted answer such as their organization" do
        event = create(:event)
        submission = create(:form_submission, role: "bulk_payment", event: event, person: nil)
        field = create(:form_field, form: submission.form, field_identifier: "payer_organization", name: "Organization")
        submission.form_answers.create!(form_field: field, submitted_answer: "Westside Shelter")

        get bulk_payments_path(search: "Westside"), headers: frame_headers

        expect(response.body).to include("form-submission-row-#{submission.id}")
      end

      it "matches on the submission metadata" do
        event = create(:event)
        submission = create(:form_submission, role: "bulk_payment", event: event, metadata: { "note" => "VIP donor" })

        get bulk_payments_path(search: "VIP donor"), headers: frame_headers

        expect(response.body).to include("form-submission-row-#{submission.id}")
      end

      it "filters by payment status" do
        event = create(:event)
        unpaid = create(:form_submission, role: "bulk_payment", event: event)
        allocated = create(:form_submission, role: "bulk_payment", event: event)
        create(:payment, form_submission: allocated, amount_cents: 1000, amount_cents_remaining: 0)
        unallocated = create(:form_submission, role: "bulk_payment", event: event)
        create(:payment, form_submission: unallocated, amount_cents: 1000, amount_cents_remaining: 500)

        get bulk_payments_path(payment_status: "unpaid"), headers: frame_headers
        expect(response.body).to include("form-submission-row-#{unpaid.id}")
        expect(response.body).not_to include("form-submission-row-#{allocated.id}")
        expect(response.body).not_to include("form-submission-row-#{unallocated.id}")

        get bulk_payments_path(payment_status: "fully_allocated"), headers: frame_headers
        expect(response.body).to include("form-submission-row-#{allocated.id}")
        expect(response.body).not_to include("form-submission-row-#{unpaid.id}")

        get bulk_payments_path(payment_status: "partially_allocated"), headers: frame_headers
        expect(response.body).to include("form-submission-row-#{unallocated.id}")
        expect(response.body).not_to include("form-submission-row-#{allocated.id}")
      end

      it "offers a Clear filters link" do
        get bulk_payments_path

        expect(response.body).to include("Clear filters")
      end

      it "tracks a view event on the full page" do
        expect(Analytics::AhoyTracker).to receive(:track_event).with(anything, "view.bulk_payments", {})
        get bulk_payments_path
      end

      it "does not track on the results frame request" do
        expect(Analytics::AhoyTracker).not_to receive(:track_event)
        get bulk_payments_path, headers: frame_headers
      end
    end

    context "as a non-admin" do
      it "is forbidden" do
        sign_in create(:user)

        get bulk_payments_path

        expect(response).not_to have_http_status(:ok)
      end
    end
  end
end
