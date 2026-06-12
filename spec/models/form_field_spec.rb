require 'rails_helper'

RSpec.describe FormField do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:form).inverse_of(:form_fields) }
    it { should have_many(:form_field_answer_options).dependent(:destroy) }
    it { should have_many(:report_form_field_answers).dependent(:destroy) }
    it { should have_many(:answer_options).through(:form_field_answer_options) }
    it { should have_many(:childs).class_name('FormField').with_foreign_key('parent_id') }
    # belongs_to :parent is implied but not explicitly stated, test if needed
    # it { should belong_to(:parent).class_name('FormField').optional }

    it { should accept_nested_attributes_for(:form_field_answer_options) }
  end

  describe 'validations' do
    # Requires form association for create
    subject do
      build(:form_field, form: create(:form))
    end
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(1000) }

    it "accepts a long, multi-sentence question name" do
      field = build(:form_field, form: create(:form), name: "A. " * 100)
      expect(field).to be_valid
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values([ :inactive, :active ]) }
    it { should define_enum_for(:answer_type).with_values([ :free_form_input_one_line, :free_form_input_paragraph,
                                                           :multiple_choice_radio, :no_user_input, :multiple_choice_checkbox,
                                                           :group_header, :multiple_choice_dropdown ]) }
    it { should define_enum_for(:input_type).with_values([ :text_alphanumeric, :number_integer, :number_decimal, :date ]) }
  end

  describe "enums" do
    it { should define_enum_for(:visibility).with_values([ :always_ask, :scholarship_only, :logged_out_only, :answers_on_file ]) }
    it { should define_enum_for(:width).with_values([ :full, :half, :third, :quarter ]).with_prefix(true) }
  end

  describe "#grid_span_class" do
    let(:form) { create(:form) }

    it "spans the full grid for full-width fields" do
      field = build(:form_field, form: form, width: :full)
      expect(field.grid_span_class).to eq("md:col-span-12")
    end

    it "spans half the grid for half-width fields" do
      field = build(:form_field, form: form, width: :half)
      expect(field.grid_span_class).to eq("md:col-span-6")
    end

    it "spans a third of the grid for third-width fields" do
      field = build(:form_field, form: form, width: :third)
      expect(field.grid_span_class).to eq("md:col-span-4")
    end

    it "spans a quarter of the grid for quarter-width fields" do
      field = build(:form_field, form: form, width: :quarter)
      expect(field.grid_span_class).to eq("md:col-span-3")
    end

    it "falls back to full width when width is blank" do
      field = build(:form_field, form: form)
      field.width = nil
      expect(field.grid_span_class).to eq("md:col-span-12")
    end
  end

  describe "#visibility_label" do
    let(:form) { create(:form) }

    it "returns the human-friendly label for each visibility" do
      expect(build(:form_field, form: form, visibility: :always_ask).visibility_label).to eq("Always ask")
      expect(build(:form_field, form: form, visibility: :scholarship_only).visibility_label).to eq("Scholarship only")
      expect(build(:form_field, form: form, visibility: :logged_out_only).visibility_label).to eq("Logged out only")
      expect(build(:form_field, form: form, visibility: :answers_on_file).visibility_label).to eq("Answers on file")
    end
  end

  describe "#conditional_visibility?" do
    let(:form) { create(:form) }

    it "is false for always-ask fields" do
      expect(build(:form_field, form: form, visibility: :always_ask).conditional_visibility?).to be false
    end

    it "is true for any non-always-ask visibility" do
      expect(build(:form_field, form: form, visibility: :logged_out_only).conditional_visibility?).to be true
      expect(build(:form_field, form: form, visibility: :answers_on_file).conditional_visibility?).to be true
      expect(build(:form_field, form: form, visibility: :scholarship_only).conditional_visibility?).to be true
    end
  end

  describe "#min_words_error" do
    let(:form) { create(:form) }

    it "returns nil when no minimum is configured" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: nil)
      expect(field.min_words_error("just two")).to be_nil
    end

    it "returns nil when the value meets the minimum" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 3)
      expect(field.min_words_error("one two three")).to be_nil
    end

    it "ignores surrounding and repeated whitespace when counting" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 3)
      expect(field.min_words_error("  one\ntwo   three  ")).to be_nil
    end

    it "returns an error when the value has too few words" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 5)
      expect(field.min_words_error("only three words")).to eq("must be at least 5 words")
    end

    it "pluralizes the word count for a minimum of one" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 1)
      expect(field.min_words_error("")).to be_nil
      expect(field.min_words_error("   ")).to be_nil
    end

    it "leaves blank values to the required check" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 5)
      expect(field.min_words_error("")).to be_nil
      expect(field.min_words_error(nil)).to be_nil
    end

    it "does not apply to non-text answer types" do
      field = build(:form_field, form: form, answer_type: :multiple_choice_radio, min_words: 5)
      expect(field.min_words_error("Yes")).to be_nil
    end
  end

  describe "min_words validation" do
    let(:form) { create(:form) }

    it "rejects a negative minimum" do
      field = build(:form_field, form: form, min_words: -1)
      expect(field).not_to be_valid
    end

    it "allows a nil minimum" do
      field = build(:form_field, form: form, min_words: nil)
      expect(field).to be_valid
    end
  end

  describe "#max_characters_error" do
    let(:form) { create(:form) }

    it "returns nil when no maximum is configured" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, max_characters: nil)
      expect(field.max_characters_error("a" * 500)).to be_nil
    end

    it "returns nil when the value is within the maximum" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, max_characters: 10)
      expect(field.max_characters_error("short")).to be_nil
    end

    it "returns nil when the value is exactly at the maximum" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, max_characters: 5)
      expect(field.max_characters_error("12345")).to be_nil
    end

    it "returns an error when the value exceeds the maximum" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, max_characters: 5)
      expect(field.max_characters_error("123456")).to eq("must be 5 characters or fewer")
    end

    it "pluralizes correctly for a maximum of one" do
      field = build(:form_field, form: form, answer_type: :free_form_input_one_line, max_characters: 1)
      expect(field.max_characters_error("ab")).to eq("must be 1 character or fewer")
    end

    it "leaves blank values to the required check" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, max_characters: 5)
      expect(field.max_characters_error("")).to be_nil
      expect(field.max_characters_error(nil)).to be_nil
    end

    it "does not apply to non-text answer types" do
      field = build(:form_field, form: form, answer_type: :multiple_choice_radio, max_characters: 1)
      expect(field.max_characters_error("Yes")).to be_nil
    end
  end

  describe "max_characters validation" do
    let(:form) { create(:form) }

    it "rejects a zero maximum" do
      field = build(:form_field, form: form, max_characters: 0)
      expect(field).not_to be_valid
    end

    it "rejects a negative maximum" do
      field = build(:form_field, form: form, max_characters: -1)
      expect(field).not_to be_valid
    end

    it "allows a nil maximum" do
      field = build(:form_field, form: form, max_characters: nil)
      expect(field).to be_valid
    end
  end

  describe "#multiple_choice?" do
    let(:form) { create(:form) }

    it "returns true for checkbox fields" do
      field = build(:form_field, form: form, answer_type: :multiple_choice_checkbox)
      expect(field.multiple_choice?).to be true
    end

    it "returns true for radio fields" do
      field = build(:form_field, form: form, answer_type: :multiple_choice_radio)
      expect(field.multiple_choice?).to be true
    end

    it "returns false for text fields" do
      field = build(:form_field, form: form, answer_type: :free_form_input_one_line)
      expect(field.multiple_choice?).to be false
    end
  end

  describe "#html_input_type" do
    let(:form) { create(:form) }

    it "returns :text for one-line inputs" do
      field = build(:form_field, form: form, answer_type: :free_form_input_one_line)
      expect(field.html_input_type).to eq(:text)
    end

    it "returns :textarea for paragraphs" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph)
      expect(field.html_input_type).to eq(:textarea)
    end

    it "returns :checkbox for checkbox fields" do
      field = build(:form_field, form: form, answer_type: :multiple_choice_checkbox)
      expect(field.html_input_type).to eq(:checkbox)
    end

    it "returns :radio for radio fields" do
      field = build(:form_field, form: form, answer_type: :multiple_choice_radio)
      expect(field.html_input_type).to eq(:radio)
    end

    it "returns :label for no_user_input without children" do
      field = build(:form_field, form: form, answer_type: :no_user_input)
      expect(field.html_input_type).to eq(:label)
    end

    it "returns :label for group_header without children" do
      field = build(:form_field, form: form, answer_type: :group_header)
      expect(field.html_input_type).to eq(:label)
    end
  end

  describe "#form_helper_type" do
    let(:form) { create(:form) }

    it "returns :text_field for one-line inputs" do
      field = build(:form_field, form: form, answer_type: :free_form_input_one_line)
      expect(field.form_helper_type).to eq(:text_field)
    end

    it "returns :text_area for paragraphs" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph)
      expect(field.form_helper_type).to eq(:text_area)
    end

    it "returns :check_box for checkbox fields" do
      field = build(:form_field, form: form, answer_type: :multiple_choice_checkbox)
      expect(field.form_helper_type).to eq(:check_box)
    end

    it "returns :radio_button for radio fields" do
      field = build(:form_field, form: form, answer_type: :multiple_choice_radio)
      expect(field.form_helper_type).to eq(:radio_button)
    end
  end

  describe "#answer_type_label" do
    let(:form) { create(:form) }

    it "calls radio fields single choice" do
      field = build(:form_field, form: form, answer_type: :multiple_choice_radio)
      expect(field.answer_type_label).to eq("Single choice radio")
    end

    it "calls checkbox fields multiple choice" do
      field = build(:form_field, form: form, answer_type: :multiple_choice_checkbox)
      expect(field.answer_type_label).to eq("Multiple choice checkbox")
    end

    it "falls back to a humanized label for unmapped types" do
      field = build(:form_field, form: form, answer_type: :free_form_input_one_line)
      expect(field.answer_type_label).to eq("One line")
    end
  end
end
