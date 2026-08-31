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
      expect(response.body).to include("Feedback")
    end

    it "redirects to the ticket when the callout has no form" do
      plain = create(:registration_ticket_callout, event:, description: "<p>Hi</p>")
      get registration_callout_form_path(registration.slug, plain)

      expect(response).to redirect_to(registration_ticket_path(registration.slug))
    end

    it "shows linked resources above the form, returning to the form page" do
      resource = create(:resource, title: "Worksheet")
      callout.resources << resource

      get registration_callout_form_path(registration.slug, callout)

      expect(response.body).to include("Worksheet")
      expect(response.body.index("Worksheet")).to be < response.body.index("callout_form[form_fields]")
      expect(response.body).to include(CGI.escapeHTML(
        registration_resource_path(registration.slug, resource, return_to: "callout_form", callout_id: callout.id)
      ))
    end
  end

  describe "POST /registration/:slug/forms/:callout_id" do
    it "records the submission and shows the answers back" do
      expect {
        post registration_callout_form_submit_path(registration.slug, callout, form),
             params: { callout_form: { form_fields: { field.id.to_s => "Loved it" } } }
      }.to change(FormSubmission, :count).by(1)

      submission = FormSubmission.last
      expect(submission).to have_attributes(person: registration.registrant, form:, event:, role: nil)
      expect(submission.collected_via_callout?).to be(true)
      expect(submission.form_answers.find_by(form_field: field).submitted_answer).to eq("Loved it")

      follow_redirect!
      expect(response.body).to include("Completed")
      expect(response.body).to include("Loved it")
    end
  end

  describe "a callout that delivers several forms, each on its own drip date" do
    let(:day1) { create(:form, name: "Day 1 Survey") }
    let(:day2) { create(:form, name: "Day 2 Survey") }
    let!(:day1_field) { create(:form_field, form: day1, name: "Day 1 highlight?") }
    let!(:day2_field) { create(:form_field, form: day2, name: "Day 2 highlight?") }
    let(:multi_callout) { create(:registration_ticket_callout, event:, description: "") }

    before do
      multi_callout.registration_ticket_callout_forms.create!(form: day1, display_from: 1.day.ago)
      multi_callout.registration_ticket_callout_forms.create!(form: day2, display_from: 1.day.from_now)
    end

    it "renders the live form and gates the not-yet-open one" do
      get registration_callout_form_path(registration.slug, multi_callout)

      expect(response.body).to include("Day 1 Survey").and include("Day 2 Survey")
      expect(response.body).to include("callout_form[form_fields][#{day1_field.id}]")
      # The dripping Day 2 form shows an "Available" chip, not its fillable field.
      expect(response.body).to include("Available")
      expect(response.body).not_to include("callout_form[form_fields][#{day2_field.id}]")
    end

    it "collapses a completed form under a Completed chip while others stay fillable" do
      post registration_callout_form_submit_path(registration.slug, multi_callout, day1),
        params: { callout_form: { form_fields: { day1_field.id.to_s => "Loved day 1" } } }

      get registration_callout_form_path(registration.slug, multi_callout)
      expect(response.body).to include("Completed")
      expect(response.body).to include("Loved day 1")
    end
  end

  describe "submitting a survey-role form (clarity fan-out + profile write-through)" do
    let(:survey) { create(:form, name: "Day 1 survey", role: "day_1_survey") }
    let!(:impact) { create(:form_field, form: survey, name: "Impact?", field_identifier: "impact") }
    let!(:anon) do
      create(:form_field, form: survey, answer_type: :single_select_radio, name: "Anonymity?",
        field_identifier: "anonymous_contributions")
    end
    let(:resource) { create(:resource, title: "Triple Focus") }
    let!(:clarity_field) do
      create(:form_field, form: survey, answer_type: :single_select_radio, name: "Was it clear for")
    end
    let(:survey_callout) { create(:registration_ticket_callout, event:, form: survey) }

    before { create(:form_field_resource, form_field: clarity_field, resource:) }

    it "records the fixed answers, fans clarity out per resource, and writes the profile through" do
      post registration_callout_form_submit_path(registration.slug, survey_callout, survey), params: {
        callout_form: {
          form_fields: {
            impact.id.to_s => "Transformative",
            anon.id.to_s => Person::ANONYMOUS_CONTRIBUTIONS_OPTIONS[true]
          },
          clarity: { clarity_field.id.to_s => { resource.id.to_s => "Yes" } }
        }
      }

      submission = FormSubmission.last
      expect(submission.role).to eq("day_1_survey")
      expect(submission.form_answers.find_by(form_field: impact).submitted_answer).to eq("Transformative")
      clarity_answer = submission.form_answers.find_by(form_field: nil)
      expect(clarity_answer.submitted_answer).to eq("Yes")
      expect(clarity_answer.question_name_when_answered).to eq("Was it clear for Triple Focus")
      expect(registration.registrant.reload.anonymous_contributions).to be(true)
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
