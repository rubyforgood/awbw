require 'rails_helper'

RSpec.describe Admin do
  let(:admin) { build(:admin) }

  # Shoulda Matchers
  describe 'associations' do
    # Add association tests here if any
    # e.g., it { should have_many(:related_models) }
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(admin).to be_valid
    end

    # Add other Devise validation tests as needed (e.g., email format, password length)
    it 'is invalid without an email' do
      admin.email = nil
      expect(admin).not_to be_valid
      expect(admin.errors[:email]).to include("can't be blank")
    end

    it 'is invalid without a password' do
      admin.password = nil
      expect(admin).not_to be_valid
      expect(admin.errors[:password]).to include("can't be blank")
    end

    # Shoulda matchers for other Devise validations (like uniqueness, format) can be complex
    # and might require database interaction (use create instead of build)
    # Example for uniqueness (requires DB):
    # subject { create(:admin) }
    # it { should validate_uniqueness_of(:email).case_insensitive }
  end
end 