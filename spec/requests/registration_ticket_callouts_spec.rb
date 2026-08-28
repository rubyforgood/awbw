require "rails_helper"

RSpec.describe "Callout inline form", type: :request do
  let(:event) { create(:event, published: true) }
  let(:registration) { create(:event_registration, event:) }
  let(:form) { create(:form, name: "Feedback") }
  let!(:field) { create(:form_field, form:, name: "How was it?") }
  let(:callout) { create(:registration_ticket_callout, event:, form:, description: "") }

  describe "GET /registration/:slug/forms/:callout_id" do
    it "renders the form for the registrant" do
      get registration_callout_form_path(registration.slug, callout)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("callout_form[form_fields][#{field.id}]")
    end

    it "redirects to the ticket when the callout has no form" do
      plain = create(:registration_ticket_callout, event:, description: "<p>Hi</p>")
      get registration_callout_form_path(registration.slug, plain)

      expect(response).to redirect_to(registration_ticket_path(registration.slug))
    end
  end

  describe "POST /registration/:slug/forms/:callout_id" do
    it "records the submission and shows the answers back" do
      expect {
        post registration_callout_form_submit_path(registration.slug, callout),
             params: { callout_form: { form_fields: { field.id.to_s => "Loved it" } } }
      }.to change(FormSubmission, :count).by(1)

      submission = FormSubmission.last
      expect(submission).to have_attributes(person: registration.registrant, form:, event:, role: "callout")
      expect(submission.form_answers.find_by(form_field: field).submitted_answer).to eq("Loved it")

      follow_redirect!
      expect(response.body).to include("your responses are recorded")
    end
  end

  describe "the generic event-scoped page" do
    it "shows a preview note instead of the interactive form" do
      get event_registration_ticket_callout_path(event, callout, reg: registration.slug)

      expect(response.body).to include("Registrants fill out")
      expect(response.body).not_to include("callout_form[form_fields]")
    end
  end
end
