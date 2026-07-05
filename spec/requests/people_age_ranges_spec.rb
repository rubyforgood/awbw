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

    # Guards against silent category loss: assign_associations only preserves
    # unmanaged taggings when the managed_category_type_ids key is posted. With no
    # profile-specific (managed) types, the per-type hidden fields render nothing,
    # so the form must still emit a blank one — otherwise the browser drops the key
    # and saving replaces categories, wiping age ranges and other-type taggings.
    it "always renders a blank managed_category_type_ids field, even with no managed types" do
      expect(CategoryType.profile_specific).to be_empty

      get edit_person_path(person)

      dom = Nokogiri::HTML(response.body)
      blank = dom.css("input[type=hidden][name='person[managed_category_type_ids][]']")
                 .any? { |node| node["value"].to_s.empty? }
      expect(blank).to be(true)
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

  describe "re-rendering after a validation error" do
    it "retains a newly chosen age range and its primary flag, with options available" do
      patch person_path(person), params: {
        person: {
          first_name: person.first_name,
          last_name: "",
          category_ids: [ "" ],
          managed_category_type_ids: [],
          age_range_categorizable_items_attributes: [
            { category_id: children.id, is_primary: "1" }
          ]
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      # The chosen age range comes back as a rendered chip, not dropped, with its
      # category_id retained in a nested-attributes field.
      expect(response.body).to include("<span>Children (0-12)</span>")
      expect(response.body).to match(/value="#{children.id}"\s+name="person\[age_range_categorizable_items_attributes\]\[\d+\]\[category_id\]"/)
      # Its primary star comes back checked.
      expect(response.body).to match(/primary-tag#selectPrimary[^>]*checked="checked"/)
      # The add picker still offers the other ranges.
      expect(response.body).to include("Teens (13-17)")
    end
  end

  describe "duplicate age-range selections" do
    it "dedupes instead of raising RecordNotUnique" do
      expect {
        update_person(age_items: [
          { category_id: children.id, is_primary: "0" },
          { category_id: children.id, is_primary: "1" }
        ])
      }.not_to raise_error

      expect(response).to have_http_status(:found)
      person.reload
      expect(person.categorizable_items.where(category: children).count).to eq(1)
      # The primary flag from the duplicate is folded onto the kept tagging.
      expect(person.primary_age_groups).to contain_exactly(children)
    end

    it "dedupes a new selection that duplicates an already-tagged range" do
      person.categories << children

      expect {
        update_person(age_items: [ { category_id: children.id, is_primary: "1" } ])
      }.not_to raise_error

      person.reload
      expect(person.categorizable_items.where(category: children).count).to eq(1)
    end
  end

  describe "more than one primary age range" do
    it "fails validation with the same single-primary rule as sectors" do
      update_person(age_items: [
        { category_id: children.id, is_primary: "1" },
        { category_id: adults.id, is_primary: "1" }
      ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Only one age range can be marked as primary")

      person.reload
      expect(person.primary_age_groups).to be_empty
    end

    it "is enforced at the model level" do
      person.age_range_categorizable_items.build(category: children, is_primary: true)
      person.age_range_categorizable_items.build(category: adults, is_primary: true)

      expect(person).not_to be_valid
      expect(person.errors[:base]).to include("Only one age range can be marked as primary")
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
