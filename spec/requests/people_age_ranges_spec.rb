require "rails_helper"

RSpec.describe "Person age ranges", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }

  # AgeGroupTaggable matches the type by the exact name "AgeRange".
  let(:age_type) { create(:category_type, :published, name: "AgeRange") }
  # Created in order so the positioned gem assigns positions children < teens < adults.
  let!(:children) { create(:category, :published, category_type: age_type, name: "Children (0-12)") }
  let!(:teens) { create(:category, :published, category_type: age_type, name: "Teens (13-17)") }
  let!(:adults) { create(:category, :published, category_type: age_type, name: "Adults (18+)") }

  # A category of some other type that the person form never shows.
  let(:art_type) { create(:category_type, :published, name: "ArtType") }
  let(:clay) { create(:category, :published, category_type: art_type, name: "Clay") }

  before { sign_in admin }

  # Age ranges are saved as age_range_categorizable_items nested attributes (the
  # cocoon picker), not category_ids. category_ids only carries workshop settings,
  # of which there are none here.
  def update_person(age_items:)
    patch person_path(person), params: {
      person: {
        first_name: person.first_name,
        category_ids: [ "" ],
        managed_category_type_ids: [],
        age_range_categorizable_items_attributes: age_items
      }
    }
  end

  describe "edit form" do
    it "renders the cocoon age-range editor with every published age range" do
      get edit_person_path(person)

      expect(response.body).to include("primary-tag")
      expect(response.body).to include("Add age range")
      expect(response.body).to include("Children (0-12)")
      expect(response.body).to include("Adults (18+)")
    end

    it "renders selected age ranges in category position order, not primary first" do
      person.categories << children << teens << adults
      # Mark the last-positioned range primary; it must NOT float to the front.
      person.categorizable_items.find_by(category: adults).update!(is_primary: true)

      get edit_person_path(person)

      body = response.body
      expect(body.index("Children (0-12)")).to be < body.index("Teens (13-17)")
      expect(body.index("Teens (13-17)")).to be < body.index("Adults (18+)")
    end
  end

  describe "saving age ranges" do
    it "tags the selected age ranges and marks the chosen one primary" do
      update_person(age_items: [
        { category_id: children.id, is_primary: "1" },
        { category_id: adults.id, is_primary: "0" }
      ])

      person.reload
      expect(person.primary_age_groups).to contain_exactly(children)
      expect(person.additional_age_groups).to contain_exactly(adults)
    end

    it "removes an age range via _destroy" do
      person.categories << children
      item = person.categorizable_items.find_by(category: children)

      update_person(age_items: [ { id: item.id, category_id: children.id, _destroy: "1" } ])

      person.reload
      expect(person.primary_age_groups).to be_empty
      expect(person.additional_age_groups).to be_empty
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

      update_person(age_items: [ { category_id: children.id, is_primary: "1" } ])

      person.reload
      expect(person.categories).to include(clay)

      surviving_item = person.categorizable_items.find_by(category: clay)
      # Same row (not destroyed + recreated) and its primary flag is unchanged.
      expect(surviving_item.id).to eq(original_item.id)
      expect(surviving_item.is_primary).to be(true)

      # And the age ranges were still applied alongside the preserved tagging.
      expect(person.primary_age_groups).to contain_exactly(children)
    end
  end
end
