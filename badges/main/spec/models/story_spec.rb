require 'rails_helper'

RSpec.describe Story do

  it 'is a type of Report' do
    expect(build(:story)).to be_a(Report)
  end

  describe 'associations' do
    # Inherited from Report
    # Add specific Story associations if any
  end

  describe 'validations' do
    # Inherited from Report
    # Add specific Story validations if any
  end

  it 'is valid with valid attributes' do
    # Note: Factory needs associations uncommented for create (from Report factory)
    # expect(build(:story)).to be_valid
    # pending("Requires functional user/project/windows_type factories and associations uncommented")
  end

  # Add tests specific to Story if any
end 