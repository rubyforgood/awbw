require "rails_helper"

RSpec.describe EventRegistrationServices::SurveySubmission do
  let(:event) { create(:event, cost_cents: 1000) }
  let(:registration) { create(:event_registration, event: event) }
  let(:person) { registration.registrant }

  let(:form) { create(:form, role: "post_event_survey") }
  let!(:static_field) do
    create(:form_field, form: form, answer_type: :free_form_input_paragraph, name: "Impact?", field_identifier: "impact")
  end
  let!(:clarity_field) do
    create(:form_field, form: form, answer_type: :single_select_radio,
      name: "Overall, was the information presented in a clear and concise manner for")
  end
  let(:triple_focus) { create(:resource, title: "Triple Focus") }
  let(:listening) { create(:resource, title: "Listening is Art") }
  let!(:anon_field) do
    create(:form_field, form: form, answer_type: :single_select_radio, name: "Anonymity?", field_identifier: "anonymous_contributions")
  end
  let!(:name_field) do
    create(:form_field, form: form, answer_type: :single_select_radio, name: "Name?", field_identifier: "display_name_preference")
  end

  before do
    create(:form_field_resource, form_field: clarity_field, resource: triple_focus)
    create(:form_field_resource, form_field: clarity_field, resource: listening)
    # Make the registrant a scholarship recipient so completion stamps.
    create(:allocation,
      source: create(:scholarship, recipient: person, tasks_completed: true, amount_cents: 100),
      allocatable: registration, amount: 100)
  end

  def submit(field_params:, clarity_params:)
    described_class.call(
      event_registration: registration, form: form, role: "post_event_survey",
      field_params: field_params, clarity_params: clarity_params
    )
  end

  let(:field_params) do
    {
      static_field.id.to_s => "It changed me",
      anon_field.id.to_s => Person::ANONYMOUS_CONTRIBUTIONS_OPTIONS[true],
      name_field.id.to_s => Person::DISPLAY_NAME_PREFERENCE_LABELS["first_name_only"]
    }
  end
  let(:clarity_params) do
    { clarity_field.id.to_s => { triple_focus.id.to_s => "Yes", listening.id.to_s => "No" } }
  end

  it "creates a role-tagged submission with the static answer" do
    service = submit(field_params: field_params, clarity_params: clarity_params)

    submission = service.submission
    expect(submission).to have_attributes(person: person, form: form, event: event, role: "post_event_survey")
    expect(submission.form_answers.find_by(form_field: static_field).submitted_answer).to eq("It changed me")
  end

  it "fans the clarity field out to one nil-field answer per resource, snapshotting the sentence" do
    service = submit(field_params: field_params, clarity_params: clarity_params)

    dynamic = service.submission.form_answers.where(form_field: nil)
    expect(dynamic.pluck(:question_name_when_answered, :submitted_answer)).to contain_exactly(
      [ "Overall, was the information presented in a clear and concise manner for Triple Focus", "Yes" ],
      [ "Overall, was the information presented in a clear and concise manner for Listening is Art", "No" ]
    )
  end

  it "writes the two profile questions through to the Person and reports the changes" do
    service = submit(field_params: field_params, clarity_params: clarity_params)

    expect(person.reload.anonymous_contributions).to be(true)
    expect(person.display_name_preference).to eq("first_name_only")
    expect(service.profile_changes).to include(
      anonymous_contributions: [ false, true ], # main's column defaults to false, not nil
      display_name_preference: [ nil, "first_name_only" ]
    )
  end

  it "stamps completion for a scholarship recipient's recipients survey" do
    submit(field_params: field_params, clarity_params: clarity_params)

    expect(registration.reload.post_survey_completed?).to be(true)
  end

  it "is idempotent on re-submit — updates in place without duplicating answers" do
    submit(field_params: field_params, clarity_params: clarity_params)
    service = submit(field_params: field_params.merge(static_field.id.to_s => "Edited"), clarity_params: clarity_params)

    expect(service.submission.form_answers.where(form_field: static_field).count).to eq(1)
    expect(service.submission.form_answers.find_by(form_field: static_field).submitted_answer).to eq("Edited")
    expect(service.submission.form_answers.where(form_field: nil).count).to eq(2)
    expect(service.profile_changes).to be_empty # unchanged the second time
  end
end
