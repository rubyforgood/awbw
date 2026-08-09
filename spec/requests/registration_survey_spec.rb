require "rails_helper"

RSpec.describe "Registration survey page", type: :request do
  let(:event) { create(:event, cost_cents: 1000) }
  let(:registration) { create(:event_registration, event: event) }
  let(:form) do
    FormBuilderService.new(name: "Post-Training Recipients Survey",
      sections: [ :recipient_survey, :content_sharing_preferences ], role: "post_event_survey").call
  end

  def make_recipient
    create(:allocation,
      source: create(:scholarship, recipient: registration.registrant, tasks_completed: true, amount_cents: 100),
      allocatable: registration, amount: 100)
  end

  def survey_callout(hidden: false, display_from: 1.day.ago)
    event.registration_ticket_callouts.create!(builtin_key: "scholarship_recipients_survey",
      title: "Scholarship recipients survey", callout_type: "action",
      hidden: hidden, display_from: display_from, form: form)
  end

  it "renders the form when live" do
    survey_callout
    get registration_survey_path(registration.slug, "scholarship_recipients_survey")
    expect(response).to have_http_status(:success)
    expect(response.body).to include("How did participating in this training impact you")
  end

  it "withholds the form before the drip date" do
    survey_callout(display_from: 3.days.from_now)
    get registration_survey_path(registration.slug, "scholarship_recipients_survey")
    expect(response.body).to include("will open on")
  end

  it "records a submission, stamps completion, and redirects" do
    make_recipient
    survey_callout
    impact = form.form_fields.find_by(field_identifier: "impact")

    expect {
      post registration_survey_submit_path(registration.slug, "scholarship_recipients_survey"),
        params: { survey: { fields: { impact.id.to_s => "It was transformative" } } }
    }.to change(FormSubmission, :count).by(1)

    expect(response).to redirect_to(registration_survey_path(registration.slug, "scholarship_recipients_survey"))
    expect(registration.reload.post_survey_completed?).to be(true)
    expect(FormSubmission.last.form_answers.find_by(form_field: impact).submitted_answer).to eq("It was transformative")
  end
end
