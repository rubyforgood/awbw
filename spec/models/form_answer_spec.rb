require "rails_helper"

RSpec.describe FormAnswer do
  describe "associations" do
    it { should belong_to(:form_field).optional }
    it { should belong_to(:form_submission) }
    it { should have_one(:asset).dependent(:destroy) }
  end

  describe "#uploaded_file" do
    let(:form) { create(:form) }
    let(:submission) { create(:form_submission, form: form) }
    let(:answer) { create(:form_answer, form_submission: submission, submitted_answer: "sample.png") }

    it "returns nil when no asset is attached" do
      expect(answer.uploaded_file).to be_nil
    end

    it "returns the attachment when a file is on file" do
      asset = answer.build_asset
      asset.file.attach(io: File.open(Rails.root.join("spec/fixtures/files/sample.png")),
                        filename: "sample.png", content_type: "image/png")
      asset.save!

      expect(answer.reload.uploaded_file).to be_attached
      expect(answer.uploaded_file.filename.to_s).to eq("sample.png")
    end
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
