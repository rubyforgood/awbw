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

    it "stores the website_url verbatim without requiring a scheme" do
      org = build(:organization, website_url: "awbw.org")
      org.valid?
      expect(org.errors[:website_url]).to be_empty
      expect(org.website_url).to eq("awbw.org")
    end
  end

  describe "#website_link_url" do
    it "prepends https:// to a bare domain" do
      org = build(:organization, website_url: "awbw.org")
      expect(org.website_link_url).to eq("https://awbw.org")
    end

    it "leaves an existing scheme unchanged" do
      org = build(:organization, website_url: "http://awbw.org")
      expect(org.website_link_url).to eq("http://awbw.org")
    end

    it "trims surrounding whitespace" do
      org = build(:organization, website_url: "  awbw.org  ")
      expect(org.website_link_url).to eq("https://awbw.org")
    end

    it "is nil when blank" do
      expect(build(:organization, website_url: "").website_link_url).to be_nil
      expect(build(:organization, website_url: nil).website_link_url).to be_nil
    end

    it "is nil when the value can't form a usable web address" do
      expect(build(:organization, website_url: "not a url").website_link_url).to be_nil
    end
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

  describe '#facilitator_status_on' do
    let(:organization) { create(:organization) }
    let(:reference_date) { Date.new(2026, 1, 1) }

    it 'is :new when the org has no facilitator affiliation before the date' do
      expect(organization.facilitator_status_on(reference_date)).to eq(:new)
    end

    it 'is :ongoing when an earlier facilitator affiliation is still active on the date' do
      create(:affiliation, organization: organization, title: "Facilitator",
             start_date: Date.new(2024, 1, 1), end_date: nil)
      expect(organization.facilitator_status_on(reference_date)).to eq(:ongoing)
    end

    it 'is :reinstated when all earlier facilitator affiliations ended before the date' do
      create(:affiliation, organization: organization, title: "Facilitator",
             start_date: Date.new(2022, 1, 1), end_date: Date.new(2023, 1, 1))
      expect(organization.facilitator_status_on(reference_date)).to eq(:reinstated)
    end

    it 'ignores an affiliation starting ON the date — the one that event mints' do
      create(:affiliation, organization: organization, title: "Facilitator",
             start_date: reference_date, end_date: nil)
      expect(organization.facilitator_status_on(reference_date)).to eq(:new)
    end

    it 'falls back to the start of the current year when given no date' do
      create(:affiliation, organization: organization, title: "Facilitator",
             start_date: Date.current.beginning_of_year - 1.day, end_date: nil)
      expect(organization.facilitator_status_on).to eq(:ongoing)
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

    context 'with program status filter' do
      it 'filters to orgs with an active facilitator affiliation' do
        create(:affiliation, organization: active_org, person: create(:person), title: "Facilitator", end_date: nil)
        results = Organization.search_by_params(program_status: "active")
        expect(results).to include(active_org)
        expect(results).not_to include(inactive_org)
      end
    end
  end

  # Buckets come from facilitator affiliations alone — the stored organization_status
  # is deliberately ignored, so each org here carries a status that contradicts its
  # affiliations (see ADR-0001 D3).
  describe ".program_status scope" do
    def org_with(status_name, **affiliation_attrs)
      create(:organization, organization_status: OrganizationStatus.find_or_create_by!(name: status_name)).tap do |org|
        next if affiliation_attrs.empty?
        create(:affiliation, organization: org, person: create(:person), title: "Facilitator", **affiliation_attrs)
      end
    end

    let!(:active_fac) { org_with("Suspended", start_date: 1.year.ago, end_date: nil) }
    let!(:lapsed_fac) { org_with("Active", start_date: 3.years.ago, end_date: 1.year.ago) }
    let!(:no_fac) { org_with("Active") }
    let!(:non_fac_only) do
      create(:organization, organization_status: OrganizationStatus.find_or_create_by!(name: "Reinstate")).tap do |org|
        create(:affiliation, organization: org, person: create(:person), title: "Volunteer", start_date: 1.year.ago, end_date: nil)
      end
    end

    it "buckets an active facilitator affiliation as active" do
      expect(Organization.program_status("active")).to contain_exactly(active_fac)
    end

    it "buckets only-lapsed facilitator affiliations as formerly_active" do
      expect(Organization.program_status("formerly_active")).to contain_exactly(lapsed_fac)
    end

    it "buckets orgs with no facilitator affiliation as never_active, whatever the stored status" do
      expect(Organization.program_status("never_active")).to contain_exactly(no_fac, non_fac_only)
    end

    it "combines formerly + never" do
      expect(Organization.program_status("formerly_or_never")).to contain_exactly(lapsed_fac, no_fac, non_fac_only)
    end
  end

  describe "search_by_params sector and age-group filters" do
    let!(:age_type) { create(:category_type, name: "AgeRange", published: true) }
    let!(:teen) { create(:category, :published, category_type: age_type, name: "13-17") }
    let!(:sector) { create(:sector, :published, name: "Housing") }
    let!(:direct_org) { create(:organization, name: "Direct Org") }
    let!(:primary_person_org) { create(:organization, name: "Primary Person Org") }
    let!(:additional_person_org) { create(:organization, name: "Additional Person Org") }
    let!(:untagged) { create(:organization, name: "Untagged Org") }

    before do
      # Tagged directly on the org (org's own tags count regardless of primary).
      direct_org.tag_age_groups(primary_ids: [], additional_ids: [ teen.id ])
      direct_org.sectorable_items.create!(sector: sector, is_primary: false)

      # An affiliated person's PRIMARY tags — should match.
      primary_person = create(:person)
      create(:affiliation, organization: primary_person_org, person: primary_person)
      primary_person.tag_age_groups(primary_ids: [ teen.id ], additional_ids: [])
      primary_person.sectorable_items.create!(sector: sector, is_primary: true)

      # An affiliated person's ADDITIONAL / non-primary tags — should NOT match.
      additional_person = create(:person)
      create(:affiliation, organization: additional_person_org, person: additional_person)
      additional_person.tag_age_groups(primary_ids: [], additional_ids: [ teen.id ])
      additional_person.sectorable_items.create!(sector: sector, is_primary: false)
    end

    it "matches a sector on the org or an affiliated person's primary, not their non-primary" do
      results = Organization.search_by_params(sector_name: "Housing")
      expect(results).to include(direct_org, primary_person_org)
      expect(results).not_to include(additional_person_org, untagged)
    end

    it "matches an age group on the org or an affiliated person's primary, not their additional" do
      results = Organization.search_by_params(age_group_name: "13-17")
      expect(results).to include(direct_org, primary_person_org)
      expect(results).not_to include(additional_person_org, untagged)
    end
  end

  describe "#all_sectors" do
    let!(:housing) { create(:sector, :published, name: "Housing") }
    let!(:legal) { create(:sector, :published, name: "Legal") }
    let!(:other) { create(:sector, :published, name: "Other Services") }
    let(:organization) { create(:organization) }

    it "includes the org's own sectors and affiliated people's primary sector only" do
      organization.sectorable_items.create!(sector: housing, is_primary: false)
      person = create(:person)
      create(:affiliation, organization: organization, person: person)
      person.sectorable_items.create!(sector: legal, is_primary: true)
      person.sectorable_items.create!(sector: other, is_primary: false)

      expect(organization.all_sectors).to contain_exactly(housing, legal)
    end
  end

  # The index caches each row, and the roll-up cells aggregate across affiliated
  # people — none of which touches the organizations row itself.
  describe "#rollup_cache_version" do
    let!(:sector) { create(:sector, :published, name: "Housing") }
    let(:organization) { create(:organization) }
    let(:person) { create(:person) }

    # A fresh instance each time, the way a page render loads it — the roll-ups
    # memoize their affiliated people, so #reload wouldn't re-read them.
    def version = Organization.find(organization.id).rollup_cache_version

    it "changes when an affiliated person is retagged" do
      create(:affiliation, organization: organization, person: person)
      before_version = version

      person.sectorable_items.create!(sector: sector, is_primary: true)

      expect(version).not_to eq(before_version)
    end

    it "changes when an affiliation is added" do
      before_version = version

      create(:affiliation, organization: organization, person: person)

      expect(version).not_to eq(before_version)
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

    it "includes org-direct age groups and affiliated people's primary (not their additional)" do
      organization.tag_age_groups(primary_ids: [ adult.id ], additional_ids: [ teen.id ])
      person_a.tag_age_groups(primary_ids: [ young.id ], additional_ids: [])
      person_b.tag_age_groups(primary_ids: [], additional_ids: [ young.id ])

      # org primary (adult) + people's primary (young); org's own additional (teen)
      # stays; person_b's additional (young) is ignored.
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

  describe ".awbw" do
    it "finds the org named by ORGANIZATION_NAME" do
      awbw = create(:organization, name: ENV.fetch("ORGANIZATION_NAME", "A Window Between Worlds"))
      create(:organization, name: "Some Partner Org")

      expect(Organization.awbw).to eq(awbw)
    end

    it "is nil when no organization matches" do
      create(:organization, name: "Some Partner Org")

      expect(Organization.awbw).to be_nil
    end
  end
end
