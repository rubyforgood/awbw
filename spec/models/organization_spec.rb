require 'rails_helper'

RSpec.describe Organization do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:location).optional }
    it { should belong_to(:windows_type).optional }
    it { should belong_to(:organization_status) }
    it { should have_many(:affiliations) }
    it { should have_many(:users).through(:people) }
    it { should have_many(:reports) }
    it { should have_many(:workshop_logs) }
  end

  describe 'validations' do
    subject { build(:organization) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:organization_status_id) }

    it { should allow_value("info@example.com").for(:email) }
    it { should allow_value("").for(:email) }
    it { should allow_value(nil).for(:email) }
    it { should_not allow_value("not-an-email").for(:email).with_message("must be a valid email address") }
  end

  it 'is valid with valid attributes' do
    # Note: Factory needs associations uncommented for create
    # expect(build(:organization)).to be_valid
  end

  describe '.address' do
    let!(:status) { create(:organization_status, name: "Active") }

    let!(:org_la) do
      org = create(:organization, name: "LA Org", organization_status: status)
      create(:address, addressable: org, street_address: "123 Main St",
             city: "Los Angeles", state: "CA", zip_code: "90001", locality: "LA City",
             county: "Los Angeles", country: "USA")
      org
    end

    let!(:org_ny) do
      org = create(:organization, name: "NY Org", organization_status: status)
      create(:address, addressable: org, street_address: "456 Broadway",
             city: "New York", state: "NY", zip_code: "10001", locality: "Outside USA",
             county: "New York", country: "USA")
      org
    end

    let!(:org_no_address) { create(:organization, name: "No Address Org", organization_status: status) }

    it 'returns all organizations when address is blank' do
      expect(Organization.address("")).to include(org_la, org_ny, org_no_address)
      expect(Organization.address(nil)).to include(org_la, org_ny, org_no_address)
    end

    it 'finds organization by city name' do
      results = Organization.address("Los Angeles")
      expect(results).to include(org_la)
      expect(results).not_to include(org_ny, org_no_address)
    end

    it 'finds organization by zip code' do
      results = Organization.address("90001")
      expect(results).to include(org_la)
      expect(results).not_to include(org_ny)
    end

    it 'finds organization by state abbreviation' do
      results = Organization.address("CA")
      expect(results).to include(org_la)
      expect(results).not_to include(org_ny)
    end

    it 'finds organization by partial street address' do
      results = Organization.address("123 Main")
      expect(results).to include(org_la)
      expect(results).not_to include(org_ny)
    end

    it 'finds organization by full address with commas' do
      results = Organization.address("123 Main St, Los Angeles, CA 90001")
      expect(results).to include(org_la)
      expect(results).not_to include(org_ny)
    end

    it 'finds organization by city and state' do
      results = Organization.address("Los Angeles, CA")
      expect(results).to include(org_la)
      expect(results).not_to include(org_ny)
    end

    it 'does not return duplicates when org has multiple matching addresses' do
      create(:address, addressable: org_la, street_address: "789 Oak Ave",
             city: "Los Angeles", state: "CA", zip_code: "90002", locality: "LA City")
      results = Organization.address("Los Angeles")
      expect(results.to_a.count { |o| o.id == org_la.id }).to eq(1)
    end

    it 'does not return organizations without addresses' do
      results = Organization.address("Los Angeles")
      expect(results).not_to include(org_no_address)
    end
  end

  describe '.search_by_params' do
    let!(:active_status) { create(:organization_status, name: "Active") }
    let!(:inactive_status) { create(:organization_status, name: "Inactive") }

    let!(:active_org) { create(:organization, name: "Community Center", organization_status: active_status) }
    let!(:inactive_org) { create(:organization, name: "Old Program", organization_status: inactive_status) }

    context 'with name query' do
      it 'searches by organization name' do
        results = Organization.search_by_params(query: "Community")
        expect(results).to include(active_org)
        expect(results).not_to include(inactive_org)
      end
    end

    context 'with address filter' do
      it 'filters by address' do
        create(:address, addressable: active_org, city: "Los Angeles", state: "CA",
               zip_code: "90001", locality: "LA City")
        results = Organization.search_by_params(address: "Los Angeles")
        expect(results).to include(active_org)
        expect(results).not_to include(inactive_org)
      end

      it 'filters by full address' do
        create(:address, addressable: active_org, street_address: "123 Main St",
               city: "Los Angeles", state: "CA", zip_code: "90001", locality: "LA City")
        results = Organization.search_by_params(address: "123 Main St, Los Angeles, CA")
        expect(results).to include(active_org)
      end
    end

    context 'with status dropdown' do
      it 'filters by organization_status_id' do
        results = Organization.search_by_params(organization_status_id: active_status.id.to_s)
        expect(results).to include(active_org)
        expect(results).not_to include(inactive_org)
      end
    end
  end
end
