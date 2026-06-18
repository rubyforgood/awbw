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

  describe "#city_state" do
    it "joins locality and state with a comma" do
      org = create(:organization)
      org.addresses.destroy_all
      create(:address, addressable: org, locality: "Los Angeles", state: "CA")

      expect(org.reload.city_state).to eq("Los Angeles, CA")
    end

    it "omits the comma when there is no locality or state" do
      org = create(:organization)
      org.addresses.destroy_all

      expect(org.reload.city_state).to eq("")
    end
  end

  describe '#facilitator_status' do
    let(:organization) { create(:organization) }
    let(:current) do
      create(:affiliation, organization: organization, title: "Facilitator", start_date: Date.new(2026, 1, 1))
    end

    it 'is :new when it is the only facilitator affiliation' do
      expect(organization.facilitator_status(current)).to eq(:new)
    end

    it 'is :new when every other facilitator affiliation started on or after it' do
      create(:affiliation, organization: organization, title: "Facilitator", start_date: Date.new(2026, 6, 1))
      expect(organization.facilitator_status(current)).to eq(:new)
    end

    it 'is :ongoing when an earlier facilitator affiliation was still active when it started' do
      create(:affiliation, organization: organization, title: "Facilitator",
             start_date: Date.new(2024, 1, 1), end_date: nil)
      expect(organization.facilitator_status(current)).to eq(:ongoing)
    end

    it 'is :reinstated when all earlier facilitator affiliations ended before it started' do
      create(:affiliation, organization: organization, title: "Facilitator",
             start_date: Date.new(2022, 1, 1), end_date: Date.new(2023, 1, 1))
      expect(organization.facilitator_status(current)).to eq(:reinstated)
    end

    it 'ignores non-facilitator affiliations when classifying' do
      create(:affiliation, organization: organization, title: "Volunteer",
             start_date: Date.new(2020, 1, 1), end_date: nil)
      expect(organization.facilitator_status(current)).to eq(:new)
    end
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

    it 'finds organization by phone number' do
      org_la.addresses.first.update!(phone: "213-555-1234")
      results = Organization.address("213-555-1234")
      expect(results).to include(org_la)
      expect(results).not_to include(org_ny)
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

  describe "age groups served" do
    let(:age_type) { create(:category_type, name: "AgeRange", published: true) }
    let!(:young) { create(:category, :published, category_type: age_type, name: "3-5") }
    let!(:teen) { create(:category, :published, category_type: age_type, name: "13-17") }
    let!(:adult) { create(:category, :published, category_type: age_type, name: "18+") }
    let(:organization) { create(:organization) }
    let(:person_a) { create(:person) }
    let(:person_b) { create(:person) }

    before do
      create(:affiliation, organization: organization, person: person_a)
      create(:affiliation, organization: organization, person: person_b)
    end

    it "aggregates and dedupes age groups across affiliated people and the org itself" do
      organization.tag_age_groups(primary_ids: [ adult.id ], additional_ids: [])
      person_a.tag_age_groups(primary_ids: [ young.id ], additional_ids: [ teen.id ])
      person_b.tag_age_groups(primary_ids: [ young.id ], additional_ids: [])

      expect(organization.all_primary_age_groups).to contain_exactly(young, adult)
      expect(organization.all_additional_age_groups).to contain_exactly(teen)
    end

    it "treats a group that is primary for any member as primary, never additional" do
      person_a.tag_age_groups(primary_ids: [ teen.id ], additional_ids: [])
      person_b.tag_age_groups(primary_ids: [], additional_ids: [ teen.id ])

      expect(organization.all_primary_age_groups).to contain_exactly(teen)
      expect(organization.all_additional_age_groups).to be_empty
    end
  end
end

RSpec.describe Organization, "scholarship index helpers" do
  describe "#program_location" do
    it "returns the City, State of the first active address" do
      org = create(:organization)
      create(:address, addressable: org, city: "Stockton", state: "CA")

      expect(org.program_location).to eq("Stockton, CA")
    end

    it "is nil without an active address" do
      expect(create(:organization).program_location).to be_nil
    end
  end

  describe "#program_status" do
    let(:org) { create(:organization) }
    let(:recipient) { create(:person) }

    it "is New when the recipient is the org's only facilitator" do
      create(:affiliation, person: recipient, organization: org, title: "Facilitator")

      expect(org.reload.program_status(recipient)).to eq("New")
    end

    it "is Ongoing when another facilitator already serves the org" do
      create(:affiliation, person: recipient, organization: org, title: "Facilitator")
      create(:affiliation, person: create(:person), organization: org, title: "Facilitator")

      expect(org.reload.program_status(recipient)).to eq("Ongoing")
    end

    it "is Reinstate when the org's facilitator affiliations have all lapsed" do
      create(:affiliation, person: recipient, organization: org, title: "Facilitator", end_date: 1.year.ago.to_date)

      expect(org.reload.program_status(recipient)).to eq("Reinstate")
    end

    it "is New when the org has no facilitator affiliations" do
      expect(org.program_status(recipient)).to eq("New")
    end
  end
end
