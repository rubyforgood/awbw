require "rails_helper"

RSpec.describe FormAnswer do
  describe "associations" do
    it { should belong_to(:form_field).optional }
    it { should belong_to(:form_submission) }
  end

  describe "#name" do
    let(:form) { create(:form) }
    let(:form_field) { create(:form_field, form: form, name: "First Name") }
    let(:submission) { create(:form_submission, form: form) }

    it "uses question_name_when_answered when present" do
      answer = create(:form_answer,
        form_submission: submission,
        form_field: form_field,
        submitted_answer: "Alice",
        question_name_when_answered: "Original Question")

      expect(answer.name).to eq("Original Question: Alice")
    end

    it "falls back to form_field.name when question_name_when_answered is blank" do
      answer = create(:form_answer,
        form_submission: submission,
        form_field: form_field,
        submitted_answer: "Alice",
        question_name_when_answered: nil)

      expect(answer.name).to eq("First Name: Alice")
    end

    it "handles deleted form_field gracefully" do
      answer = create(:form_answer,
        form_submission: submission,
        form_field: nil,
        submitted_answer: "Alice",
        question_name_when_answered: "Deleted Question")

      expect(answer.name).to eq("Deleted Question: Alice")
    end
  end
end
