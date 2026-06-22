require "rails_helper"

RSpec.describe "Person age ranges", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }

  # AgeGroupTaggable matches the type by the exact name "AgeRange".
  let(:age_type) { create(:category_type, :published, name: "AgeRange") }
  let!(:children) { create(:category, :published, category_type: age_type, name: "Children (0-12)") }
  let!(:adults) { create(:category, :published, category_type: age_type, name: "Adults (18+)") }

  # A category of some other type that the person form never shows.
  let(:art_type) { create(:category_type, :published, name: "ArtType") }
  let(:clay) { create(:category, :published, category_type: art_type, name: "Clay") }

  before { sign_in admin }

  def update_person(category_ids:, primary_age_category_ids: [])
    patch person_path(person), params: {
      person: {
        first_name: person.first_name,
        category_ids: category_ids,
        primary_age_category_ids: primary_age_category_ids,
        managed_category_type_ids: [ age_type.id ]
      }
    }
  end

  describe "edit form" do
    it "renders the age-range chip picker with every published age range" do
      get edit_person_path(person)

      expect(response.body).to include("age-range-picker")
      expect(response.body).to include("Children (0-12)")
      expect(response.body).to include("Adults (18+)")
    end
  end

  describe "saving age ranges" do
    it "tags the selected age ranges and marks the chosen ones primary" do
      update_person(category_ids: [ children.id, adults.id ], primary_age_category_ids: [ children.id ])

      person.reload
      expect(person.primary_age_groups).to contain_exactly(children)
      expect(person.additional_age_groups).to contain_exactly(adults)
    end
  end

  describe "preserving non-AgeRange category connections" do
    before do
      person.categories << clay
      # Give the Clay tagging a primary flag so we can prove it is left untouched.
      person.categorizable_items.find_by(category: clay).update!(is_primary: true)
    end

    it "does not delete or edit the person's non-AgeRange category connections" do
      original_item = person.categorizable_items.find_by(category: clay)

      # The form only ever submits age-range ids in category_ids — Clay is not on
      # the form. Saving must keep it anyway.
      update_person(category_ids: [ children.id ], primary_age_category_ids: [ children.id ])

      person.reload
      expect(person.categories).to include(clay)

      surviving_item = person.categorizable_items.find_by(category: clay)
      # Same row (not destroyed + recreated) and its primary flag is unchanged.
      expect(surviving_item.id).to eq(original_item.id)
      expect(surviving_item.is_primary).to be(true)

      # And the age ranges were still applied alongside the preserved tagging.
      expect(person.primary_age_groups).to contain_exactly(children)
    end

    it "clears age ranges without touching the non-AgeRange tagging" do
      update_person(category_ids: [ "" ])

      person.reload
      expect(person.primary_age_groups).to be_empty
      expect(person.additional_age_groups).to be_empty
      expect(person.categories).to include(clay)
    end
  end
end
