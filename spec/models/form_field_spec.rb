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
    it { should validate_presence_of(:question) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values([:inactive, :active]) }
    it { should define_enum_for(:answer_type).with_values([:free_form_input_one_line, :free_form_input_paragraph, 
                                                            :multiple_choice_radio, :no_user_input, :multiple_choice_checkbox,
                                                            :group_header]) }
    it { should define_enum_for(:answer_datatype).with_values([:text_alphanumeric, :number_integer, :number_decimal, :date,]) }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs form association uncommented for create
  #   # expect(build(:form_field)).to be_valid
  #   pending("Requires functional form factory and association uncommented")
  # end

  # Add tests for methods like #name, #multiple_choice?, #html_id, etc.
end 