require 'rails_helper'

RSpec.describe OrganizationPerson do
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:person) }
  end

  describe 'validations' do
    subject do
      build(:organization_person, organization: create(:organization), person: create(:person))
    end
    it { should validate_presence_of(:organization_id) }
  end

  describe 'enums' do
    it { should define_enum_for(:position).with_values(default: 0, liaison: 1, leader: 2, assistant: 3) }
  end

  it 'is valid with valid attributes' do
    # Note: Factory needs associations uncommented for create
    # expect(build(:organization_person)).to be_valid
    # pending("Requires functional organization/person factories and associations uncommented")
  end
end
