require 'rails_helper'

RSpec.describe FormBuilder do

  describe 'associations' do
    it { should belong_to(:windows_type) }
    it { should have_many(:forms) }
    it { should accept_nested_attributes_for(:forms) }
  end

  describe 'validations' do
    subject { build(:form_builder, windows_type: create(:windows_type)) }
    it { should validate_presence_of(:name) }
  end

  it 'is valid with valid attributes' do
    # Note: Factory needs windows_type association uncommented for create
    # expect(build(:form_builder)).to be_valid
  end

  # Add tests for methods like #report_type, #form_fields etc.
  # Add tests for scopes :workshop_logs, :monthly
end