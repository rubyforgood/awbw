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

  describe "#sync_uploaded_filename!" do
    let(:form) { create(:form) }
    let(:submission) { create(:form_submission, form: form) }
    let(:answer) { create(:form_answer, form_submission: submission, submitted_answer: "stale.png") }

    it "caches the attached file's name" do
      answer.build_asset.tap do |asset|
        asset.file.attach(io: File.open(Rails.root.join("spec/fixtures/files/sample.png")),
                          filename: "sample.png", content_type: "image/png")
        asset.save!
      end

      answer.sync_uploaded_filename!

      expect(answer.submitted_answer).to eq("sample.png")
    end

    it "clears the cache when there is no attachment" do
      answer.sync_uploaded_filename!

      expect(answer.submitted_answer).to eq("")
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

  describe ".for_question" do
    let(:form) { create(:form, :standalone) }
    let(:field) { create(:form_field, form: form, name: "How clear was", answer_type: :single_select_radio) }

    before { create(:form_field_resource, form_field: field, resource: create(:resource, title: "Masks")) }

    it "is the field's own answers under its name" do
      own = create(:form_answer, form_field: field, form_submission: create(:form_submission, form: form))

      expect(described_class.for_question(field, "How clear was")).to contain_exactly(own)
    end

    it "is a fanned-out copy's answers under its sentence, on the field's form only" do
      copy = create(:form_answer, form_field: nil, question_name_when_answered: "How clear was Masks",
                    form_submission: create(:form_submission, form: form))
      create(:form_answer, form_field: nil, question_name_when_answered: "How clear was Masks",
             form_submission: create(:form_submission, form: create(:form, :standalone)))

      expect(described_class.for_question(field, "How clear was Masks")).to contain_exactly(copy)
    end

    it "is a renamed resource's earlier answers under its earlier wording" do
      earlier = create(:form_answer, form_field: nil, question_name_when_answered: "How clear was Collage",
                       form_submission: create(:form_submission, form: form))

      expect(described_class.for_question(field, "How clear was Collage")).to contain_exactly(earlier)
    end

    it "is nil for wording the field doesn't ask" do
      expect(described_class.for_question(field, "Was it clear")).to be_nil
    end

    it "is nil for a non-choice field's sibling name" do
      email = create(:form_field, form: form, name: "Email")

      expect(described_class.for_question(email, "Email 2")).to be_nil
    end
  end
end
