require "rails_helper"

RSpec.describe CategoriesTaggable do
  let(:story) { create(:story) }
  let(:population) { create(:category_type, :published, name: CategoriesTaggable::AUDIENCE_CATEGORY_TYPE) }
  let(:children) { create(:category, :published, name: "Children", category_type: population) }
  let(:teens) { create(:category, :published, name: "Teens", category_type: population) }

  describe "single-primary validation" do
    it "allows one primary category" do
      story.categorizable_items.build(category: children, is_primary: true)
      story.categorizable_items.build(category: teens, is_primary: false)

      expect(story).to be_valid
    end

    it "rejects two primary categories" do
      story.categorizable_items.build(category: children, is_primary: true)
      story.categorizable_items.build(category: teens, is_primary: true)

      expect(story).not_to be_valid
      expect(story.errors[:base]).to include("Only one story population can be marked as primary")
    end

    it "rejects a primary category outside story population" do
      story.categorizable_items.build(category: create(:category, :published), is_primary: true)

      expect(story).not_to be_valid
      expect(story.errors[:base]).to include("Only a story population category can be marked as primary")
    end

    it "rejects two primary categories on a story idea" do
      story_idea = create(:story_idea)
      story_idea.categorizable_items.build(category: children, is_primary: true)
      story_idea.categorizable_items.build(category: teens, is_primary: true)

      expect(story_idea).not_to be_valid
    end
  end

  describe "#primary_category" do
    it "returns the category marked primary" do
      story.categorizable_items.create!(category: children, is_primary: false)
      story.categorizable_items.create!(category: teens, is_primary: true)

      expect(story.primary_category).to eq(teens)
    end

    it "is nil when no category is primary" do
      story.categorizable_items.create!(category: children, is_primary: false)

      expect(story.primary_category).to be_nil
    end
  end
end
