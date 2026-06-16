require "rails_helper"

RSpec.describe "FormSubmissions", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:submission) { create(:form_submission) }

  describe "GET /form_submissions/:id" do
    context "as an admin" do
      before { sign_in admin }

      it "renders the submission" do
        field = create(:form_field, form: submission.form, name: "Organization")
        create(:form_answer, form_submission: submission, form_field: field, submitted_answer: "AWBW")

        get form_submission_path(submission)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Organization")
        expect(response.body).to include("AWBW")
      end
    end

    context "when arriving from the bulk payments index" do
      before { sign_in admin }

      let(:event) { create(:event) }

      before do
        EventForm.create!(event: event, form: submission.form, role: "bulk_payment")
        submission.update!(role: "bulk_payment")
      end

      it "points the back link at bulk payments" do
        get form_submission_path(submission, return_to: "bulk_payments")

        expect(response.body).to include(bulk_payments_event_path(event))
        expect(response.body).to include("Back to bulk payments")
      end

      it "points the back link at the event without the return_to context" do
        get form_submission_path(submission)

        expect(response.body).to include("Back to event")
        expect(response.body).not_to include("Back to bulk payments")
      end
    end

    context "as a non-admin" do
      before { sign_in create(:user) }

      it "redirects away" do
        get form_submission_path(submission)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
