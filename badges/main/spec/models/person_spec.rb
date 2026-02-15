require "rails_helper"

RSpec.describe Person, type: :model do
  describe "associations" do
    it { should have_one(:user) }
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
