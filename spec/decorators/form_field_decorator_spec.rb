require "rails_helper"

RSpec.describe FormFieldDecorator do
  let(:form) { create(:form) }

  describe "#anchor_id" do
    it "uses the record id once saved" do
      field = create(:form_field, form:)
      expect(field.decorate.anchor_id(3)).to eq("form_field_#{field.id}")
    end

    it "falls back to the editor list position for a new question" do
      expect(build(:form_field, form:).decorate.anchor_id(3)).to eq("new_form_field_3")
    end
  end

  describe "#error_label" do
    it "numbers and quotes the question" do
      expect(build(:form_field, name: "Rate the facilitator").decorate.error_label(2)).to eq("Question 2 “Rate the facilitator”")
    end

    it "marks a question with no text as untitled" do
      expect(build(:form_field, name: "").decorate.error_label(4)).to eq("Question 4 (untitled)")
    end
  end

  describe "#error_messages" do
    it "lists the question's own errors and quotes each over-long answer option" do
      field = build(:form_field, form:, name: "x" * 1001, answer_type: :single_select_radio)
      field.form_field_answer_options.build.option_name = "y" * 300
      field.valid?

      expect(field.decorate.error_messages).to contain_exactly(
        "Question text is too long (1001 characters; the limit is 1000)",
        a_string_matching(/\AAnswer option “y{37}\.\.\.” is too long \(300 characters; the limit is 255\)\z/)
      )
      expect(field.decorate.answer_option_errors?).to be(true)
    end
  end
end
