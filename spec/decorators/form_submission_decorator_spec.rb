require "rails_helper"

RSpec.describe FormSubmissionDecorator do
  describe "#payer_name / #payer_email" do
    it "uses the linked person's account when present" do
      person = build(:person, first_name: "Priya", last_name: "Patel", email: "priya@example.com")
      submission = build(:form_submission, person: person).decorate

      expect(submission.payer_name).to eq(person.name)
      expect(submission.payer_email).to eq("priya@example.com")
    end

    it "falls back to the submitted answers for an account-less payer" do
      submission = create(:form_submission, person: nil, role: "bulk_payment")
      first = create(:form_field, form: submission.form, field_identifier: "first_name", name: "First name")
      last = create(:form_field, form: submission.form, field_identifier: "last_name", name: "Last name")
      email = create(:form_field, form: submission.form, field_identifier: "primary_email", name: "Email")
      submission.form_answers.create!(form_field: first, submitted_answer: "Dana")
      submission.form_answers.create!(form_field: last, submitted_answer: "Doe")
      submission.form_answers.create!(form_field: email, submitted_answer: "dana@example.com")

      expect(submission.decorate.payer_name).to eq("Dana Doe")
      expect(submission.decorate.payer_email).to eq("dana@example.com")
    end

    it "returns a neutral placeholder when there is neither an account nor a typed name" do
      submission = create(:form_submission, person: nil, role: "bulk_payment").decorate

      expect(submission.payer_name).to eq("Anonymous payer")
      expect(submission.payer_email).to be_nil
    end
  end
end
