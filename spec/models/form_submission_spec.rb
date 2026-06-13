require "rails_helper"

RSpec.describe FormSubmission do
  describe "associations" do
    it { should belong_to(:person) }
    it { should belong_to(:form) }
    it { should have_many(:form_answers).dependent(:destroy) }
    it { should accept_nested_attributes_for(:form_answers) }
  end

  describe "#event" do
    it "returns the event whose join role matches the submission role" do
      event = create(:event)
      form = create(:form)
      event.event_forms.create!(form: form, role: "bulk_payment")
      submission = create(:form_submission, form: form, role: "bulk_payment")

      expect(submission.event).to eq(event)
    end
  end

  describe "#answers_by_identifier" do
    it "maps submitted answers by their field identifier" do
      form = create(:form)
      field = create(:form_field, form: form, field_identifier: "payer_email", name: "Payer email")
      submission = create(:form_submission, form: form)
      submission.form_answers.create!(form_field: field, submitted_answer: "pat@example.com")

      expect(submission.answers_by_identifier["payer_email"]).to eq("pat@example.com")
    end
  end

  describe "#bulk_payment_attendees" do
    let(:form) { create(:form) }
    let(:field) { create(:form_field, form: form, field_identifier: "bulk_payment_attendees", name: "Attendees") }
    let(:submission) { create(:form_submission, form: form) }

    it "parses the attendees JSON array" do
      submission.form_answers.create!(form_field: field, submitted_answer: [ { first_name: "A", email: "a@example.com" } ].to_json)

      expect(submission.bulk_payment_attendees).to eq([ { "first_name" => "A", "email" => "a@example.com" } ])
    end

    it "returns an empty array for invalid JSON" do
      submission.form_answers.create!(form_field: field, submitted_answer: "not json")

      expect(submission.bulk_payment_attendees).to eq([])
    end
  end
end
