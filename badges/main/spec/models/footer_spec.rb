require 'rails_helper'

RSpec.describe Footer do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    # Add association tests if any
  end

  describe 'validations' do
    # Add validation tests if any
    # e.g., it { should validate_presence_of(:phone) }
  end

  # Basic validity test
  it 'is valid with valid attributes' do
    expect(build(:footer)).to be_valid
  end

  # Tests for class methods remain relevant
  describe 'class methods' do
    # Ensure one record exists, clear others if necessary for reliable .first
    let!(:footer_record) { create(:footer) }
    before { Footer.where.not(id: footer_record.id).delete_all } 

    it '.phone returns the phone number' do
      expect(Footer.phone).to eq(footer_record.phone)
    end

    it '.general_questions returns the general questions info' do
      expect(Footer.general_questions).to eq(footer_record.general_questions)
    end
  end
end 