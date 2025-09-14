require 'rails_helper'

RSpec.describe Organization, type: :model do
  describe 'associations' do
    it { should have_many(:addresses).dependent(:destroy) }
    it { should have_many(:facilitator_organizations).dependent(:restrict_with_exception) }
    it { should have_many(:facilitators).through(:facilitator_organizations) }
    it { should have_many(:organization_workshops).dependent(:restrict_with_exception) }
    it { should have_many(:workshops).through(:organization_workshops) }
  end

  describe 'validations' do
    let(:organization) { build(:organization) }

    it 'is valid with valid attributes' do
      expect(organization).to be_valid
    end

    it 'requires a name' do
      organization.name = nil
      expect(organization).not_to be_valid
      expect(organization.errors[:name]).to include("can't be blank")
    end

    it 'requires an agency_type' do
      organization.agency_type = nil
      expect(organization).not_to be_valid
      expect(organization.errors[:agency_type]).to include("can't be blank")
    end

    it 'requires a phone' do
      organization.phone = nil
      expect(organization).not_to be_valid
      expect(organization.errors[:phone]).to include("can't be blank")
    end
  end

  describe 'default values' do
    it 'defaults is_active to true' do
      organization = create(:organization)
      expect(organization.is_active).to be true
    end
  end

  describe 'optional fields' do
    let(:organization) { build(:organization) }

    it 'allows start_date to be nil' do
      organization.start_date = nil
      expect(organization).to be_valid
    end

    it 'allows close_date to be nil' do
      organization.close_date = nil
      expect(organization).to be_valid
    end

    it 'allows website_url to be nil' do
      organization.website_url = nil
      expect(organization).to be_valid
    end

    it 'allows agency_type_other to be nil' do
      organization.agency_type_other = nil
      expect(organization).to be_valid
    end

    it 'allows mission to be nil' do
      organization.mission = nil
      expect(organization).to be_valid
    end

    it 'allows project_id to be nil' do
      organization.project_id = nil
      expect(organization).to be_valid
    end
  end

  describe 'string representations' do
    it 'has a valid website URL when present' do
      organization = create(:organization)
      if organization.website_url.present?
        expect(organization.website_url).to start_with("http")
      end
    end
  end
end
