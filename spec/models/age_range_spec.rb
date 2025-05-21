require 'rails_helper'

RSpec.describe AgeRange do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:windows_type) }
  end

  describe 'validations' do
    # Add validation tests if any exist (e.g., name)
    # subject { build(:age_range) } # Might need windows_type for create
    # it { should validate_presence_of(:name) }
  end

  it 'is valid with valid attributes' do
    # Note: Factory might need windows_type association uncommented for create
    expect(build(:age_range)).to be_valid
  end
end 