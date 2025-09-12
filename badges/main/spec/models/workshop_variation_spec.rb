require 'rails_helper'

RSpec.describe WorkshopVariation do

  describe 'associations' do
    it { should belong_to(:workshop) }
  end

  describe 'validations' do
    # Add validation tests if any (e.g., presence of name, code?)
    # subject { build(:workshop_variation) } # Requires workshop
    # it { should validate_presence_of(:name) }
    # it { should validate_presence_of(:code) }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs association uncommented for create
  #   # expect(build(:workshop_variation)).to be_valid
  #   pending("Requires functional workshop factory and association uncommented")
  # end
end 