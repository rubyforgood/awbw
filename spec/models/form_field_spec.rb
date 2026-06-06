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
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values([ :inactive, :active ]) }
    it { should define_enum_for(:answer_type).with_values([ :free_form_input_one_line, :free_form_input_paragraph,
                                                           :multiple_choice_radio, :no_user_input, :multiple_choice_checkbox,
                                                           :group_header ]) }
    it { should define_enum_for(:input_type).with_values([ :text_alphanumeric, :number_integer, :number_decimal, :date ]) }
  end

  describe "enums" do
    it { should define_enum_for(:visibility).with_values([ :always_ask, :scholarship_only, :logged_out_only, :answers_on_file ]) }
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
end
