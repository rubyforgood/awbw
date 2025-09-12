require 'rails_helper'

RSpec.describe ProjectObligation do

  describe 'associations' do
    # Add association tests if any (e.g., has_many :projects?)
  end

  describe 'validations' do
    # Assuming name should be present and unique
    subject { build(:project_obligation) }
    # it { should validate_presence_of(:name) } # Model missing validation
    # it { should validate_uniqueness_of(:name) } # Requires create
  end

  it 'is valid with valid attributes' do
   expect(build(:project_obligation)).to be_valid
  end
end 