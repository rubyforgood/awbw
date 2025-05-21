require 'rails_helper'

RSpec.describe MonthlyReport do
  it 'is a type of Report' do
    expect(build(:monthly_report)).to be_a(Report)
  end

  describe 'associations' do
    # Inherited from Report
    # Add specific MonthlyReport associations if any
  end

  describe 'validations' do
    # Inherited from Report
    # Add specific MonthlyReport validations if any
  end

  it 'is valid with valid attributes' do
    # Note: Factory needs associations uncommented for create (from Report factory)
    # expect(build(:monthly_report)).to be_valid
    # pending("Requires functional user/project/windows_type factories and associations")
  end

  # Add tests specific to MonthlyReport if any
end