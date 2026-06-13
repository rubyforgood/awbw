require "rails_helper"

RSpec.describe Person, type: :model do
  describe "associations" do
    it { should have_one(:user) }
    it { should belong_to(:created_by).class_name("User").optional(true) }
    it { should belong_to(:updated_by).class_name("User").optional(true) }
    it { should have_many(:affiliations).dependent(:destroy) }
    it { should have_many(:organizations).through(:affiliations) }
    it { should have_many(:addresses) }
    it { should have_many(:contact_methods) }
    it { should have_many(:sectorable_items) }
  end

  describe "strip_whitespace" do
    let(:admin) { create(:user, :admin) }

    it "strips leading and trailing whitespace from names and emails" do
      person = create(:person, first_name: "  Jane  ", last_name: "  Doe  ",
                       email: "  jane@test.org  ", email_2: "  jane2@test.org  ",
                       created_by: admin, updated_by: admin)
      expect(person.first_name).to eq("Jane")
      expect(person.last_name).to eq("Doe")
      expect(person.email).to eq("jane@test.org")
      expect(person.email_2).to eq("jane2@test.org")
    end

    it "handles nil values" do
      person = create(:person, first_name: "Jane", last_name: "Doe",
                       email: nil, email_2: nil,
                       created_by: admin, updated_by: admin)
      expect(person.email).to be_nil
      expect(person.email_2).to be_nil
    end
  end

  describe "validations" do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }

    it { should allow_value("test@example.com").for(:email) }
    it { should allow_value("").for(:email) }
    it { should allow_value(nil).for(:email) }
    it { should_not allow_value("not-an-email").for(:email).with_message("must be a valid email address") }

    it { should allow_value("test@example.com").for(:email_2) }
    it { should allow_value("").for(:email_2) }
    it { should_not allow_value("not-an-email").for(:email_2).with_message("must be a valid email address") }

    describe "unique_name_and_email_combination" do
      let(:admin) { create(:user, :admin) }

      it "prevents duplicate person with same name and email" do
        create(:person, first_name: "Jane", last_name: "Doe", email: "jane@test.org",
               created_by: admin, updated_by: admin)
        duplicate = build(:person, first_name: "Jane", last_name: "Doe", email: "jane@test.org",
                          created_by: admin, updated_by: admin)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:base]).to include(/already exists/)
      end

      it "is case insensitive on name" do
        create(:person, first_name: "Jane", last_name: "Doe", email: "jane@test.org",
               created_by: admin, updated_by: admin)
        duplicate = build(:person, first_name: "JANE", last_name: "DOE", email: "jane@test.org",
                          created_by: admin, updated_by: admin)
        expect(duplicate).not_to be_valid
      end

      it "is case insensitive on email" do
        create(:person, first_name: "Jane", last_name: "Doe", email: "Jane@Test.org",
               created_by: admin, updated_by: admin)
        duplicate = build(:person, first_name: "Jane", last_name: "Doe", email: "jane@test.org",
                          created_by: admin, updated_by: admin)
        expect(duplicate).not_to be_valid
      end

      it "allows same name with different email" do
        create(:person, first_name: "Jane", last_name: "Doe", email: "jane@test.org",
               created_by: admin, updated_by: admin)
        different_email = build(:person, first_name: "Jane", last_name: "Doe", email: "other@test.org",
                                created_by: admin, updated_by: admin)
        expect(different_email).to be_valid
      end

      it "allows same email with different name" do
        create(:person, first_name: "Jane", last_name: "Doe", email: "jane@test.org",
               created_by: admin, updated_by: admin)
        different_name = build(:person, first_name: "John", last_name: "Smith", email: "jane@test.org",
                               created_by: admin, updated_by: admin)
        expect(different_name).to be_valid
      end

      it "treats blank and nil emails as equivalent" do
        create(:person, first_name: "Jane", last_name: "Doe", email: nil,
               created_by: admin, updated_by: admin)
        duplicate = build(:person, first_name: "Jane", last_name: "Doe", email: "",
                          created_by: admin, updated_by: admin)
        expect(duplicate).not_to be_valid
      end

      it "allows updating the existing record itself" do
        person = create(:person, first_name: "Jane", last_name: "Doe", email: "jane@test.org",
                        created_by: admin, updated_by: admin)
        person.bio = "updated"
        expect(person).to be_valid
      end
    end
  end

  describe "primary sector validation (SectorsTaggable)" do
    let(:person) { build(:person) }
    let(:sector_a) { create(:sector, :published) }
    let(:sector_b) { create(:sector, :published) }

    it "is valid with no primary sectors" do
      person.sectorable_items.build(sector: sector_a, is_primary: false)
      person.sectorable_items.build(sector: sector_b, is_primary: false)
      expect(person).to be_valid
    end

    it "is valid with exactly one primary sector" do
      person.sectorable_items.build(sector: sector_a, is_primary: true)
      person.sectorable_items.build(sector: sector_b, is_primary: false)
      expect(person).to be_valid
    end

    it "is invalid with more than one primary sector" do
      person.sectorable_items.build(sector: sector_a, is_primary: true)
      person.sectorable_items.build(sector: sector_b, is_primary: true)
      expect(person).not_to be_valid
      expect(person.errors[:base]).to include("Only one sector can be marked as primary")
    end

    it "ignores sectorable_items marked for destruction" do
      person.sectorable_items.build(sector: sector_a, is_primary: true)
      doomed = person.sectorable_items.build(sector: sector_b, is_primary: true)
      doomed.mark_for_destruction
      expect(person).to be_valid
    end
  end

  describe "#sectorable_items_primary_first" do
    it "orders the primary sector first, then the rest alphabetically" do
      person = create(:person)
      zebra = create(:sector, :published, name: "Zebra")
      apple = create(:sector, :published, name: "Apple")
      mango = create(:sector, :published, name: "Mango")
      person.sectorable_items.create!(sector: zebra, is_primary: false)
      person.sectorable_items.create!(sector: mango, is_primary: true)
      person.sectorable_items.create!(sector: apple, is_primary: false)

      person.reload
      expect(person.sectorable_items_primary_first.map { |si| si.sector.name }).to eq(%w[Mango Apple Zebra])
    end
  end

  describe "#name" do
    let(:person) { build(:person, first_name: "Jane", last_name: "Doe") }

    context "when display_name_preference is full_name" do
      it "returns the full name" do
        person.display_name_preference = "full_name"
        expect(person.name).to eq("Jane Doe")
      end
    end

    context "when display_name_preference is first_name_last_initial" do
      it "returns first name and last initial" do
        person.display_name_preference = "first_name_last_initial"
        expect(person.name).to eq("Jane D")
      end
    end

    context "when display_name_preference is first_name_only" do
      it "returns only the first name" do
        person.display_name_preference = "first_name_only"
        expect(person.name).to eq("Jane")
      end
    end

    context "when display_name_preference is last_name_only" do
      it "returns only the last name" do
        person.display_name_preference = "last_name_only"
        expect(person.name).to eq("Doe")
      end
    end

    context "when display_name_preference is nil or unknown" do
      it "defaults to full name" do
        person.display_name_preference = nil
        expect(person.name).to eq("Jane Doe")
      end
    end
  end

  describe "#published?" do
    let(:person) { create(:person, profile_is_searchable: true) }

    context "when person is searchable with an active affiliation" do
      before { create(:affiliation, person: person, inactive: false, end_date: nil) }

      it "returns true" do
        expect(person.published?).to be true
      end
    end

    context "when person is searchable but has no affiliations" do
      it "returns false" do
        expect(person.published?).to be false
      end
    end

    context "when person is searchable but only has inactive affiliations" do
      before { create(:affiliation, person: person, inactive: true, end_date: nil) }

      it "returns false" do
        expect(person.published?).to be false
      end
    end

    context "when person is searchable but affiliation has past end date" do
      before { create(:affiliation, person: person, inactive: false, end_date: 1.day.ago) }

      it "returns false" do
        expect(person.published?).to be false
      end
    end

    context "when person is not searchable" do
      let(:person) { create(:person, profile_is_searchable: false) }
      before { create(:affiliation, person: person, inactive: false) }

      it "returns false" do
        expect(person.published?).to be false
      end
    end
  end

  describe ".with_active_affiliations" do
    let!(:person_with_active) { create(:person) }
    let!(:person_with_inactive) { create(:person) }
    let!(:person_without) { create(:person) }

    before do
      create(:affiliation, person: person_with_active, inactive: false, end_date: nil)
      create(:affiliation, person: person_with_inactive, inactive: true, end_date: nil)
    end

    it "includes people with active affiliations" do
      expect(Person.with_active_affiliations).to include(person_with_active)
    end

    it "excludes people with only inactive affiliations" do
      expect(Person.with_active_affiliations).not_to include(person_with_inactive)
    end

    it "excludes people with no affiliations" do
      expect(Person.with_active_affiliations).not_to include(person_without)
    end
  end

  describe "#full_name" do
    it "returns first and last name" do
      person = build(:person, first_name: "Jane", last_name: "Doe")
      expect(person.full_name).to eq("Jane Doe")
    end
  end

  describe "#primary_organization" do
    let(:person) { create(:person) }

    it "returns the most recently updated active organization" do
      org1 = create(:organization)
      org2 = create(:organization)
      create(:affiliation, person: person, organization: org1, inactive: false, end_date: nil, updated_at: 1.day.ago)
      create(:affiliation, person: person, organization: org2, inactive: false, end_date: nil, updated_at: Time.current)
      expect(person.primary_organization).to eq(org2)
    end

    it "returns nil when no active affiliations exist" do
      create(:affiliation, person: person, inactive: true)
      expect(person.primary_organization).to be_nil
    end

    it "returns nil when person has no affiliations" do
      expect(person.primary_organization).to be_nil
    end
  end

  describe "user association" do
    it "links to a user" do
      person = create(:person)
      expect(person.user).to be_a(User)
    end

    it "can exist without a user" do
      admin = create(:user, :admin)
      person = Person.create!(first_name: "Solo", last_name: "Person",
                              created_by: admin, updated_by: admin)
      expect(person.user).to be_nil
    end
  end

  describe '.search_by_params' do
    let(:org_alpha) { create(:organization, name: "Alpha Center") }
    let(:org_beta) { create(:organization, name: "Beta Foundation") }

    let!(:person_alice) do
      create(:person, first_name: 'Alice', last_name: 'Smith', email: 'alice@example.com').tap do |p|
        create(:affiliation, person: p, organization: org_alpha)
      end
    end

    let!(:person_bob) do
      create(:person, first_name: 'Bob', last_name: 'Jones', email: 'bob@example.com').tap do |p|
        create(:affiliation, person: p, organization: org_beta)
      end
    end

    it 'returns all when no params' do
      results = Person.search_by_params({})
      expect(results).to include(person_alice, person_bob)
    end

    it 'filters by contact_info matching name' do
      results = Person.search_by_params(contact_info: 'Alice')
      expect(results).to include(person_alice)
      expect(results).not_to include(person_bob)
    end

    it 'filters by contact_info matching email' do
      results = Person.search_by_params(contact_info: 'bob@example')
      expect(results).to include(person_bob)
      expect(results).not_to include(person_alice)
    end

    it 'filters by organization_name' do
      results = Person.search_by_params(organization_name: 'Alpha')
      expect(results).to include(person_alice)
      expect(results).not_to include(person_bob)
    end

    it 'chains contact_info and organization_name' do
      results = Person.search_by_params(contact_info: 'Alice', organization_name: 'Alpha')
      expect(results).to include(person_alice)
      expect(results).not_to include(person_bob)
    end

    it 'chains with_active_affiliations and organization_name without an ambiguous end_date error' do
      expect {
        Person.with_active_affiliations.search_by_params(organization_name: 'Alpha').to_a
      }.not_to raise_error
    end
  end

  describe ".published" do
    let!(:searchable_with_active) do
      person = create(:person, profile_is_searchable: true)
      create(:affiliation, person: person, inactive: false, end_date: nil)
      person
    end

    let!(:searchable_without_active) do
      create(:person, profile_is_searchable: true)
    end

    let!(:not_searchable_with_active) do
      person = create(:person, profile_is_searchable: false)
      create(:affiliation, person: person, inactive: false, end_date: nil)
      person
    end

    it "includes searchable people with active affiliations" do
      expect(Person.published).to include(searchable_with_active)
    end

    it "excludes searchable people without active affiliations" do
      expect(Person.published).not_to include(searchable_without_active)
    end

    it "excludes non-searchable people even with active affiliations" do
      expect(Person.published).not_to include(not_searchable_with_active)
    end
  end
end
