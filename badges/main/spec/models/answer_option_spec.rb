require 'rails_helper'

RSpec.describe AnswerOption do
  describe 'associations' do
    # Add association tests here if any are added later
    # e.g., it { should have_many(:form_field_answer_options) }
    # e.g., it { should have_many(:form_fields).through(:form_field_answer_options) }
  end

  describe 'validations' do
    # Add validation tests here if any are added later
    # e.g., it { should validate_presence_of(:text) }
  end

  # Example basic validity test (optional if using shoulda matchers)
  it 'is valid with valid attributes' do
    expect(build(:answer_option)).to be_valid
  end
end 