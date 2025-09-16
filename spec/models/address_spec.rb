require 'rails_helper'

RSpec.describe Address, type: :model do
  describe 'associations' do
    it { should belong_to(:organization) }
  end

  describe 'validations' do
    let(:address) { build(:address) }

    it 'is valid with valid attributes' do
      expect(address).to be_valid
    end

    it 'requires a street' do
      address.street = nil
      expect(address).not_to be_valid
      expect(address.errors[:street]).to include("can't be blank")
    end

    it 'requires a city' do
      address.city = nil
      expect(address).not_to be_valid
      expect(address.errors[:city]).to include("can't be blank")
    end

    it 'requires a state' do
      address.state = nil
      expect(address).not_to be_valid
      expect(address.errors[:state]).to include("can't be blank")
    end

    it 'requires a zip' do
      address.zip = nil
      expect(address).not_to be_valid
      expect(address.errors[:zip]).to include("can't be blank")
    end

    it 'requires an organization' do
      address.organization = nil
      expect(address).not_to be_valid
      expect(address.errors[:organization]).to include("must exist")
    end
  end

  describe 'optional fields' do
    let(:address) { build(:address) }

    it 'allows country to be nil' do
      address.country = nil
      expect(address).to be_valid
    end

    it 'allows locality to be nil' do
      address.locality = nil
      expect(address).to be_valid
    end

    it 'allows county to be nil' do
      address.county = nil
      expect(address).to be_valid
    end

    it 'allows LA-specific fields to be nil' do
      address.la_city_council_district = nil
      address.la_supervisorial_district = nil
      address.la_service_planning_area = nil
      expect(address).to be_valid
    end
  end
end
