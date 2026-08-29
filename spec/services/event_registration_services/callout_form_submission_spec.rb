require "rails_helper"

RSpec.describe EventRegistrationServices::CalloutFormSubmission do
  let(:event) { create(:event) }
  let(:registration) { create(:event_registration, event:) }
  let(:form) { create(:form) }
  let!(:field) { create(:form_field, form:, name: "How was it?") }
  let(:callout) { create(:registration_ticket_callout, event:, form:) }

  it "records the answers under the form's own role (nil for a role-less form)" do
    submission = described_class.call(
      registration:, callout:, form_params: { field.id.to_s => "Great" }
    )

    expect(submission).to have_attributes(
      person: registration.registrant, form:, event:, role: nil
    )
    expect(submission.form_answers.find_by(form_field: field).submitted_answer).to eq("Great")
  end

  it "carries the form's own role when it has one" do
    form.update!(role: "post_event_survey")

    submission = described_class.call(registration:, callout:, form_params: { field.id.to_s => "Great" })

    expect(submission.role).to eq("post_event_survey")
  end

  it "records in metadata that the submission was collected via a callout" do
    submission = described_class.call(registration:, callout:, form_params: { field.id.to_s => "Great" })

    expect(submission.collected_via_callout?).to be(true)
    expect(submission.metadata["collected_via_callout_id"]).to eq(callout.id)
  end

  it "edits the existing submission in place on re-submit" do
    described_class.call(registration:, callout:, form_params: { field.id.to_s => "Great" })

    expect {
      submission = described_class.call(registration:, callout:, form_params: { field.id.to_s => "Even better" })
      expect(submission.form_answers.find_by(form_field: field).submitted_answer).to eq("Even better")
    }.not_to change(FormSubmission, :count)
  end
end
