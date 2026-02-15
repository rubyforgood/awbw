require "rails_helper"

RSpec.describe Person, type: :model do
  describe "associations" do
    it { should have_one(:user) }
    it { should belong_to(:created_by).class_name("User") }
    it { should belong_to(:updated_by).class_name("User") }
    it { should have_many(:organization_people).dependent(:destroy) }
    it { should have_many(:organizations).through(:organization_people) }
    it { should have_many(:addresses) }
    it { should have_many(:contact_methods) }
    it { should have_many(:sectorable_items) }
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
      before { create(:organization_person, person: person, inactive: false, end_date: nil) }

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
      before { create(:organization_person, person: person, inactive: true, end_date: nil) }

      it "returns false" do
        expect(person.published?).to be false
      end
    end

    context "when person is searchable but affiliation has past end date" do
      before { create(:organization_person, person: person, inactive: false, end_date: 1.day.ago) }

      it "returns false" do
        expect(person.published?).to be false
      end
    end

    context "when person is not searchable" do
      let(:person) { create(:person, profile_is_searchable: false) }
      before { create(:organization_person, person: person, inactive: false) }

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
      create(:organization_person, person: person_with_active, inactive: false, end_date: nil)
      create(:organization_person, person: person_with_inactive, inactive: true, end_date: nil)
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
      create(:organization_person, person: person, organization: org1, inactive: false, end_date: nil, updated_at: 1.day.ago)
      create(:organization_person, person: person, organization: org2, inactive: false, end_date: nil, updated_at: Time.current)
      expect(person.primary_organization).to eq(org2)
    end

    it "returns nil when no active affiliations exist" do
      create(:organization_person, person: person, inactive: true)
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

  describe ".published" do
    let!(:searchable_with_active) do
      person = create(:person, profile_is_searchable: true)
      create(:organization_person, person: person, inactive: false, end_date: nil)
      person
    end

    let!(:searchable_without_active) do
      create(:person, profile_is_searchable: true)
    end

    let!(:not_searchable_with_active) do
      person = create(:person, profile_is_searchable: false)
      create(:organization_person, person: person, inactive: false, end_date: nil)
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
