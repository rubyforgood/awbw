require "rails_helper"

RSpec.describe "RegistrationTicketCallouts", type: :request do
  let(:event) { create(:event, published: true) }
  let(:registration) { create(:event_registration, event:) }
  let(:form) { create(:form, name: "Feedback") }
  let!(:field) { create(:form_field, form:, name: "How was it?") }
  let(:callout) { create(:registration_ticket_callout, event:, form:, description: "") }

  describe "GET /show with an attached form" do
    it "renders the form for the registrant" do
      get event_registration_ticket_callout_path(event, callout, reg: registration.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("callout_form[form_fields][#{field.id}]")
    end

    it "shows a preview note when viewed without a registrant" do
      get event_registration_ticket_callout_path(event, callout)

      expect(response.body).to include("Registrants see")
      expect(response.body).not_to include("callout_form[form_fields]")
    end
  end

  describe "POST /submit_form" do
    it "records the submission and shows the answers back" do
      expect {
        post submit_form_event_registration_ticket_callout_path(event, callout, reg: registration.slug),
             params: { callout_form: { form_fields: { field.id.to_s => "Loved it" } } }
      }.to change(FormSubmission, :count).by(1)

      submission = FormSubmission.last
      expect(submission).to have_attributes(person: registration.registrant, form:, event:, role: "callout")
      expect(submission.form_answers.find_by(form_field: field).submitted_answer).to eq("Loved it")

      follow_redirect!
      expect(response.body).to include("your responses are recorded")
    end
  end
end
