require 'rails_helper'

RSpec.describe ProjectStatus do

  describe 'associations' do
  end

  describe 'validations' do
    subject { build(:project_status) }
  end

  it 'is valid with valid attributes' do
    expect(build(:project_status)).to be_valid
  end
end 