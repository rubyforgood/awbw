require 'rails_helper'

RSpec.describe WindowsType do

  describe 'associations' do
    it { should have_many(:workshops) }
    it { should have_many(:age_ranges) }
    it { should have_many(:reports) }
    it { should have_many(:form_builders) }
  end

  describe 'validations' do
    subject { build(:windows_type) }
  end

  it 'is valid with valid attributes' do
    expect(build(:windows_type)).to be_valid
  end

  # Add tests for methods like #label, #log_label, etc.
end 