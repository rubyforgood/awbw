require "rails_helper"

RSpec.describe EventRegistrationServices::CalloutFormSubmission do
  let(:event) { create(:event) }
  let(:registration) { create(:event_registration, event:) }
  let(:form) { create(:form) }
  let!(:field) { create(:form_field, form:, name: "How was it?") }
  let(:callout) { create(:registration_ticket_callout, event:, form:) }

  it "records the answers for the registrant, falling back to the callout role for a role-less form" do
    submission = described_class.call(
      registration:, callout:, form_params: { field.id.to_s => "Great" }
    )

    expect(submission).to have_attributes(
      person: registration.registrant, form:, event:, role: "callout"
    )
    expect(submission.form_answers.find_by(form_field: field).submitted_answer).to eq("Great")
  end

  it "mirrors the form's own role when it has one" do
    form.update!(role: "post_event_survey")

    submission = described_class.call(registration:, callout:, form_params: { field.id.to_s => "Great" })

    expect(submission.role).to eq("post_event_survey")
  end

  it "guards a reserved event-form role, falling back to the callout role" do
    form.update!(role: "scholarship")

    submission = described_class.call(registration:, callout:, form_params: { field.id.to_s => "Great" })

    expect(submission.role).to eq("callout")
  end

  it "edits the existing submission in place on re-submit" do
    described_class.call(registration:, callout:, form_params: { field.id.to_s => "Great" })

    expect {
      submission = described_class.call(registration:, callout:, form_params: { field.id.to_s => "Even better" })
      expect(submission.form_answers.find_by(form_field: field).submitted_answer).to eq("Even better")
    }.not_to change(FormSubmission, :count)
  end
end
