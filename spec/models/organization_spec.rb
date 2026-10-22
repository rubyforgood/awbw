require 'rails_helper'

RSpec.describe Organization do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:location).optional }
    it { should belong_to(:windows_type).optional }
    it { should belong_to(:organization_status).optional }
    it { should belong_to(:parent).class_name("Organization").optional }
    it { should have_many(:children).class_name("Organization").with_foreign_key(:parent_id).dependent(:nullify) }
    it { should have_many(:affiliations) }
    it { should have_many(:users).through(:people) }
    it { should have_many(:reports) }
    it { should have_many(:workshop_logs) }
    it { should have_many(:workshop_ideas) }
    it { should have_many(:workshops) }
    it { should have_many(:workshops_as_author).through(:people) }
    it { should have_many(:workshop_ideas_as_author).through(:people) }
  end

  describe 'validations' do
    subject { build(:organization) }
    it { should validate_presence_of(:name) }
    it { should_not validate_presence_of(:organization_status_id) }
    it { should validate_uniqueness_of(:name).case_insensitive }

    it "strips surrounding whitespace from the name" do
      expect(build(:organization, name: "  Hope House  ").name).to eq("Hope House")
    end

    it "rejects a name that differs only by case or trailing whitespace" do
      create(:organization, name: "Hope House")
      expect(build(:organization, name: "hope house ")).not_to be_valid
    end

    it "is enforced by a unique index when validations are skipped" do
      create(:organization, name: "Hope House")
      duplicate = build(:organization, name: "HOPE HOUSE")
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique, /index_organizations_on_name/)
    end

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

  describe "nesting" do
    let(:parent) { create(:organization) }
    let(:child) { create(:organization, parent: parent) }
    let(:grandchild) { create(:organization, parent: child) }

    it "exposes children and reports nested?" do
      expect(parent.children).to include(child)
      expect(child.nested?).to be(true)
      expect(parent.nested?).to be(false)
    end

    it "walks ancestors up to the root" do
      expect(grandchild.ancestors).to eq([ child, parent ])
      expect(grandchild.root).to eq(parent)
      expect(parent.root).to eq(parent)
    end

    it "collects descendants at any depth" do
      grandchild
      expect(parent.descendants).to match_array([ child, grandchild ])
    end

    it "un-nests children when the parent is destroyed" do
      child
      parent.destroy
      expect(child.reload.parent_id).to be_nil
    end

    it "rejects making an org its own parent" do
      parent.parent = parent
      expect(parent).not_to be_valid
      expect(parent.errors[:parent_id]).to be_present
    end

    it "rejects nesting an org under one of its own descendants" do
      grandchild
      parent.parent = grandchild
      expect(parent).not_to be_valid
      expect(parent.errors[:parent_id]).to be_present
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
    let!(:upcoming_fac) { org_with("Active", start_date: 1.month.from_now, end_date: nil) }
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

    it "buckets a not-yet-started facilitator affiliation as upcoming" do
      expect(Organization.program_status("upcoming")).to contain_exactly(upcoming_fac)
    end

    it "buckets only-lapsed facilitator affiliations as formerly_active (excludes upcoming)" do
      expect(Organization.program_status("formerly_active")).to contain_exactly(lapsed_fac)
    end

    it "buckets orgs with no facilitator affiliation as never_active, whatever the stored status" do
      expect(Organization.program_status("never_active")).to contain_exactly(no_fac, non_fac_only)
    end

    it "combines formerly + never + upcoming under the Inactive (not-active) umbrella" do
      expect(Organization.program_status("formerly_or_never")).to contain_exactly(lapsed_fac, no_fac, non_fac_only, upcoming_fac)
    end
  end

  describe "search_by_params sector and age-group filters" do
    let!(:age_type) { create(:category_type, name: "AgeRange", published: true) }
    let!(:teen) { create(:category, :published, category_type: age_type, name: "13-17") }
    let!(:sector) { create(:sector, :published, name: "Housing") }
    let!(:direct_org) { create(:organization, name: "Direct Org") }
    let!(:primary_person_org) { create(:organization, name: "Primary Person Org") }
    let!(:additional_person_org) { create(:organization, name: "Additional Person Org") }
    let!(:inactive_person_org) { create(:organization, name: "Inactive Person Org") }
    let!(:staff_org) { create(:organization, name: "Staff Org") }

    before do
      direct_org.categorizable_items.create!(category: teen)
      direct_org.sectorable_items.create!(sector: sector, is_primary: false)

      primary_person = create(:person)
      create(:affiliation, organization: primary_person_org, person: primary_person)
      primary_person.tag_age_groups(primary_ids: [ teen.id ], additional_ids: [])
      primary_person.sectorable_items.create!(sector: sector, is_primary: true)

      additional_person = create(:person)
      create(:affiliation, organization: additional_person_org, person: additional_person)
      additional_person.tag_age_groups(primary_ids: [], additional_ids: [ teen.id ])
      additional_person.sectorable_items.create!(sector: sector, is_primary: false)

      former_person = create(:person)
      create(:affiliation, organization: inactive_person_org, person: former_person, end_date: 1.year.ago)
      former_person.tag_age_groups(primary_ids: [ teen.id ], additional_ids: [])
      former_person.sectorable_items.create!(sector: sector, is_primary: true)

      staff_person = create(:person)
      create(:affiliation, organization: staff_org, person: staff_person, title: "Director")
      staff_person.tag_age_groups(primary_ids: [ teen.id ], additional_ids: [])
      staff_person.sectorable_items.create!(sector: sector, is_primary: true)
    end

    it "matches a sector through an active facilitator's primary or additional tag" do
      expect(Organization.search_by_params(sector_name: "Housing")).to contain_exactly(primary_person_org, additional_person_org)
    end

    it "matches an age group through an active facilitator's primary or additional tag" do
      expect(Organization.search_by_params(age_group_name: "13-17")).to contain_exactly(primary_person_org, additional_person_org)
    end
  end

  describe ".category_names_all for the org's own category types" do
    let(:settings_type) { create(:category_type, name: "WorkshopEnvironment", published: true, profile_specific: true) }
    let!(:clinical) { create(:category, :published, category_type: settings_type, name: "Clinical setting") }

    def tagged_org(name, affiliation_attrs)
      create(:organization, name: name).tap do |organization|
        organization.categorizable_items.create!(category: clinical)
        create(:affiliation, { organization: organization }.merge(affiliation_attrs))
      end
    end

    it "matches only organizations that also have an active facilitator, like the matrix counts" do
      facilitating = tagged_org("Facilitating Org", {})
      tagged_org("Staff Only Org", title: "Director")
      tagged_org("Former Org", end_date: 1.year.ago)

      expect(Organization.category_names_all("Clinical setting")).to contain_exactly(facilitating)
      expect(Organization.category_tag_counts).to eq(clinical.id => 1)
      expect(Category.has_published_taggings).to contain_exactly(clinical)
    end
  end

  describe "#active_facilitator_sectors" do
    let!(:housing) { create(:sector, :published, name: "Housing") }
    let!(:legal) { create(:sector, :published, name: "Legal") }
    let!(:other) { create(:sector, :published, name: "Other Services") }
    let(:organization) { create(:organization) }

    it "rolls up only active facilitators' primary sectors, ignoring the org's own tags and other staff" do
      organization.sectorable_items.create!(sector: housing, is_primary: true)
      person = create(:person)
      create(:affiliation, organization: organization, person: person)
      person.sectorable_items.create!(sector: legal, is_primary: true)
      person.sectorable_items.create!(sector: other, is_primary: false)
      former = create(:person)
      create(:affiliation, organization: organization, person: former, end_date: 1.year.ago)
      former.sectorable_items.create!(sector: housing, is_primary: true)
      staff = create(:person)
      create(:affiliation, organization: organization, person: staff, title: "Director")
      staff.sectorable_items.create!(sector: other, is_primary: true)

      expect(organization.active_facilitator_sectors).to contain_exactly(legal)
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

  describe "#active_facilitator_age_group_breakdown" do
    let(:age_type) { create(:category_type, name: "AgeRange", published: true) }
    let!(:adults) { create(:category, :published, category_type: age_type, name: "Adults") }
    let!(:elders) { create(:category, :published, category_type: age_type, name: "Elders") }
    let!(:teens) { create(:category, :published, category_type: age_type, name: "Teens") }
    let!(:children) { create(:category, :published, category_type: age_type, name: "Children") }
    let(:organization) { create(:organization) }

    def facilitator(primary:, additional: [])
      person = create(:person)
      create(:affiliation, organization: organization, person: person)
      person.tag_age_groups(primary_ids: primary.map(&:id), additional_ids: additional.map(&:id))
    end

    it "orders by primary holders, then additional holders, then name" do
      facilitator(primary: [ teens ], additional: [ adults ])
      facilitator(primary: [ children ], additional: [ adults ])
      facilitator(primary: [ elders ], additional: [ adults, teens ])

      rows = organization.active_facilitator_age_group_breakdown
      expect(rows.map { |row| row.tag.name }).to eq(%w[Teens Children Elders Adults])
      expect(rows.map { |row| [ row.primary_count, row.additional_count ] }).to eq([ [ 1, 1 ], [ 1, 0 ], [ 1, 0 ], [ 0, 3 ] ])
    end
  end

  describe "#active_facilitator_age_groups" do
    let(:age_type) { create(:category_type, name: "AgeRange", published: true) }
    let!(:young) { create(:category, :published, category_type: age_type, name: "3-5") }
    let!(:teen) { create(:category, :published, category_type: age_type, name: "13-17") }
    let!(:adult) { create(:category, :published, category_type: age_type, name: "18+") }
    let(:organization) { create(:organization) }
    let(:person_a) { create(:person) }
    let(:person_b) { create(:person) }
    let(:former) { create(:person) }

    before do
      create(:affiliation, organization: organization, person: person_a)
      create(:affiliation, organization: organization, person: person_b)
      create(:affiliation, organization: organization, person: former, end_date: 1.year.ago)
    end

    it "rolls up only active facilitators' primary age groups, ignoring the org's own tags and other staff" do
      organization.categorizable_items.create!(category: adult, is_primary: true)
      person_a.tag_age_groups(primary_ids: [ young.id ], additional_ids: [])
      person_b.tag_age_groups(primary_ids: [ young.id ], additional_ids: [ teen.id ])
      former.tag_age_groups(primary_ids: [ adult.id ], additional_ids: [])
      staff = create(:person)
      create(:affiliation, organization: organization, person: staff, title: "Director")
      staff.tag_age_groups(primary_ids: [ teen.id ], additional_ids: [])

      expect(organization.active_facilitator_age_groups).to contain_exactly(young)
    end

    it "orders by how many facilitators hold it as primary, then by age position" do
      person_a.tag_age_groups(primary_ids: [ adult.id ], additional_ids: [])
      person_b.tag_age_groups(primary_ids: [ teen.id ], additional_ids: [])
      third = create(:person)
      create(:affiliation, organization: organization, person: third)
      third.tag_age_groups(primary_ids: [ teen.id ], additional_ids: [])
      fourth = create(:person)
      create(:affiliation, organization: organization, person: fourth)
      fourth.tag_age_groups(primary_ids: [ young.id ], additional_ids: [])

      expect(organization.active_facilitator_age_groups).to eq([ teen, young, adult ])
    end
  end

  describe "#affiliated_workshops" do
    let(:organization) { create(:organization) }
    let(:affiliated_person) { create(:person) }
    let(:windows_type) { create(:windows_type, :adult) }

    before do
      create(:affiliation, organization: organization, person: affiliated_person)
    end

    it "includes directly associated workshops and workshops authored by affiliated people without duplicates" do
      direct_workshop = create(:workshop, organization: organization, windows_type: windows_type)
      authored_workshop = create(:workshop, author: affiliated_person, windows_type: windows_type)
      both_workshop = create(:workshop, organization: organization, author: affiliated_person, windows_type: windows_type)
      unrelated_workshop = create(:workshop, windows_type: windows_type)

      results = organization.affiliated_workshops

      expect(results).to include(direct_workshop, authored_workshop, both_workshop)
      expect(results).not_to include(unrelated_workshop)
      expect(results.where(id: both_workshop.id).count).to eq(1)
    end
  end

  describe "#affiliated_workshop_ideas" do
    let(:organization) { create(:organization) }
    let(:affiliated_person) { create(:person) }
    let(:windows_type) { create(:windows_type, :adult) }
    let(:admin) { create(:user, :admin) }

    before do
      create(:affiliation, organization: organization, person: affiliated_person)
    end

    it "includes directly associated ideas and ideas authored by affiliated people without duplicates" do
      direct_idea = create(:workshop_idea, organization: organization, windows_type: windows_type, created_by: admin)
      authored_idea = create(:workshop_idea, author: affiliated_person, windows_type: windows_type, created_by: admin)
      both_idea = create(:workshop_idea, organization: organization, author: affiliated_person, windows_type: windows_type, created_by: admin)
      unrelated_idea = create(:workshop_idea, windows_type: windows_type, created_by: admin)

      results = organization.affiliated_workshop_ideas

      expect(results).to include(direct_idea, authored_idea, both_idea)
      expect(results).not_to include(unrelated_idea)
      expect(results.where(id: both_idea.id).count).to eq(1)
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

  describe "FileMaker codes" do
    it "parses a trimmed, de-duplicated list from the column" do
      org = build(:organization, filemaker_code: " FM1 , FM2,FM1 ")

      expect(org.filemaker_codes).to eq(%w[FM1 FM2])
    end

    it "is empty when the column is blank" do
      expect(build(:organization, filemaker_code: nil).filemaker_codes).to eq([])
    end

    it "combines mixed strings and lists into one sorted normalized value" do
      expect(Organization.join_filemaker_codes("FM2, FM1", " FM3 ", nil, "FM1")).to eq("FM1, FM2, FM3")
    end

    it "returns nil when there is nothing to combine" do
      expect(Organization.join_filemaker_codes(nil, "")).to be_nil
    end
  end
end
