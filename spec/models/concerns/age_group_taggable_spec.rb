require "rails_helper"

# Person is used as the host model; the concern is also mixed into Organization
# and exercised there via the aggregation specs.
RSpec.describe AgeGroupTaggable do
  let(:age_type) { create(:category_type, name: "AgeRange", published: true) }
  let!(:young) { create(:category, :published, category_type: age_type, name: "3-5") }
  let!(:teen) { create(:category, :published, category_type: age_type, name: "13-17") }
  let!(:adult) { create(:category, :published, category_type: age_type, name: "18+") }
  # A non-age category to prove the concern leaves other taggings alone.
  let(:setting_type) { create(:category_type, name: "WorkshopEnvironment", published: true) }
  let!(:clinical) { create(:category, :published, category_type: setting_type, name: "Clinical setting") }

  let(:person) { create(:person) }

  describe "#tag_age_groups" do
    it "tags primary and additional age groups with the right is_primary flag" do
      person.tag_age_groups(primary_ids: [ young.id ], additional_ids: [ teen.id, adult.id ])

      expect(person.primary_age_groups).to contain_exactly(young)
      expect(person.additional_age_groups).to contain_exactly(teen, adult)
    end

    it "treats a category named in both lists as primary" do
      person.tag_age_groups(primary_ids: [ young.id ], additional_ids: [ young.id, teen.id ])

      expect(person.primary_age_groups).to contain_exactly(young)
      expect(person.additional_age_groups).to contain_exactly(teen)
    end

    it "is additive — it preserves age groups and other categories tagged earlier" do
      person.categories << clinical
      person.tag_age_groups(primary_ids: [ young.id ], additional_ids: [])
      person.tag_age_groups(primary_ids: [], additional_ids: [ teen.id ])

      expect(person.primary_age_groups).to contain_exactly(young)
      expect(person.additional_age_groups).to contain_exactly(teen)
      expect(person.categories).to include(clinical)
    end
  end

  describe "#apply_primary_age_groups!" do
    it "flips is_primary on already-tagged age categories to match the given set" do
      person.categories = [ young, teen, adult ]

      person.apply_primary_age_groups!([ young.id, teen.id ])

      expect(person.primary_age_groups).to contain_exactly(young, teen)
      expect(person.additional_age_groups).to contain_exactly(adult)
    end

    it "clears primary when the set is empty and never creates new taggings" do
      person.tag_age_groups(primary_ids: [ young.id ], additional_ids: [])

      person.apply_primary_age_groups!([])

      expect(person.primary_age_groups).to be_empty
      expect(person.additional_age_groups).to contain_exactly(young)
    end
  end

  describe "#primary_age_category_ids" do
    it "returns the ids of the currently-primary age groups" do
      person.tag_age_groups(primary_ids: [ adult.id ], additional_ids: [ teen.id ])

      expect(person.primary_age_category_ids).to contain_exactly(adult.id)
    end
  end
end
