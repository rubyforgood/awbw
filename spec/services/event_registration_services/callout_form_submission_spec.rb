require "rails_helper"

RSpec.describe EventRegistrationServices::CalloutFormSubmission do
  let(:event) { create(:event) }
  let(:registration) { create(:event_registration, event:) }
  let(:form) { create(:form) }
  let!(:field) { create(:form_field, form:, name: "How was it?") }
  let(:callout) { create(:registration_ticket_callout, event:, form:) }

  it "records the answers as a callout-role submission for the registrant" do
    submission = described_class.call(
      registration:, callout:, form_params: { field.id.to_s => "Great" }
    )

    expect(submission).to have_attributes(
      person: registration.registrant, form:, event:, role: "callout"
    )
    expect(submission.form_answers.find_by(form_field: field).submitted_answer).to eq("Great")
  end

  it "edits the existing submission in place on re-submit" do
    described_class.call(registration:, callout:, form_params: { field.id.to_s => "Great" })

    expect {
      submission = described_class.call(registration:, callout:, form_params: { field.id.to_s => "Even better" })
      expect(submission.form_answers.find_by(form_field: field).submitted_answer).to eq("Even better")
    }.not_to change(FormSubmission, :count)
  end
end
