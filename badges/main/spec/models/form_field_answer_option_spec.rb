require 'rails_helper'

RSpec.describe FormFieldAnswerOption do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:form_field) }
    it { should belong_to(:answer_option) }
  end

  describe 'validations' do
    # Add validation tests if any (e.g., presence)
    # subject { build(:form_field_answer_option) } # Requires associations
    # it { should validate_presence_of(:form_field_id) }
    # it { should validate_presence_of(:answer_option_id) }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs associations uncommented for create
  #   # expect(build(:form_field_answer_option)).to be_valid
  #   pending("Requires functional form_field/answer_option factories and associations uncommented")
  # end
end 