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

    it "keeps only one primary — a newly chosen primary demotes the previous one" do
      person.tag_age_groups(primary_ids: [ young.id ], additional_ids: [])
      person.tag_age_groups(primary_ids: [ teen.id ], additional_ids: [])

      expect(person.primary_age_groups).to contain_exactly(teen)
      expect(person.additional_age_groups).to contain_exactly(young)
    end
  end

  describe "#apply_primary_age_groups!" do
    it "marks a single primary age category, demoting the rest, honoring only the first id" do
      person.categories = [ young, teen, adult ]

      person.apply_primary_age_groups!([ young.id, teen.id ])

      expect(person.primary_age_groups).to contain_exactly(young)
      expect(person.additional_age_groups).to contain_exactly(teen, adult)
    end

    it "clears primary when the set is empty and never creates new taggings" do
      person.tag_age_groups(primary_ids: [ young.id ], additional_ids: [])

      person.apply_primary_age_groups!([])

      expect(person.primary_age_groups).to be_empty
      expect(person.additional_age_groups).to contain_exactly(young)
    end
  end

  describe "single-primary validation" do
    it "is invalid when more than one age range is marked primary" do
      person.categorizable_items.create!(category: young, is_primary: true)
      person.categorizable_items.create!(category: teen, is_primary: true)

      expect(person.reload).not_to be_valid
      expect(person.errors[:base]).to include("Only one age range can be marked as primary")
    end

    it "is valid with a single primary age range" do
      person.tag_age_groups(primary_ids: [ young.id ], additional_ids: [ teen.id ])

      expect(person.reload).to be_valid
    end
  end

  describe "#primary_age_category_ids" do
    it "returns the ids of the currently-primary age groups" do
      person.tag_age_groups(primary_ids: [ adult.id ], additional_ids: [ teen.id ])

      expect(person.primary_age_category_ids).to contain_exactly(adult.id)
    end
  end
end
