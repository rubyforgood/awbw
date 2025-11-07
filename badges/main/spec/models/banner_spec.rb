require 'rails_helper'

RSpec.describe Banner, type: :model do
  let(:banner) { build(:banner) } # Keep if needed for other tests

  describe 'associations' do
    # Add association tests if any
  end

  describe 'validations' do
    subject { build(:banner) }
    it { should validate_presence_of(:content) }
  end

  # Basic validity test included via shoulda
  # it 'is valid with valid attributes' do
  #   expect(build(:banner)).to be_valid
  # end
end
