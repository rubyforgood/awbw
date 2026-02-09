require 'rails_helper'

RSpec.describe OrganizationStatus do
  describe 'associations' do
  end

  describe 'validations' do
    subject { build(:organization_status) }
  end

  it 'is valid with valid attributes' do
    expect(build(:organization_status)).to be_valid
  end
end
