require "rails_helper"

RSpec.describe "Stories and story ideas change log", type: :request do
  before { sign_in create(:user, :admin) }

  describe "story edit page" do
    it_behaves_like "a page with a change log" do
      let(:record) { create(:story) }
      let(:page_path) { edit_story_path(record) }
    end

    it "names a removed sector from the label recorded with the change" do
      story = create(:story)
      create(
        :ahoy_event,
        name: "update.story",
        resource_type: "Story",
        resource_id: story.id,
        properties: {
          resource_type: "Story", resource_id: story.id,
          association_changes: { primary_sector: [ { action: "removed", type: "Sector", id: 0, label: "Retired sector" } ] }
        }
      )

      get edit_story_path(story)

      expect(response.body).to include("Retired sector")
    end
  end

  describe "story idea edit page" do
    it_behaves_like "a page with a change log" do
      let(:record) { create(:story_idea) }
      let(:page_path) { edit_story_idea_path(record) }
    end
  end

  describe "recording a primary change" do
    let(:arts) { create(:sector, :published, name: "Arts") }
    let(:bio) { create(:sector, :published, name: "Bio") }
    let(:population) { create(:category_type, :published, name: CategoriesTaggable::STORY_POPULATION_CATEGORY_TYPE) }
    let(:teens) { create(:category, :published, name: "Teens", category_type: population) }

    it "logs the primary sector and story population moving on the story's own event" do
      story = create(:story, :published)
      story.sectorable_items.create!(sector: arts, is_primary: true)
      pushed = []
      allow(Analytics::LifecycleBuffer).to receive(:push).and_wrap_original { |push, event| pushed << event; push.call(event) }

      patch story_path(story), params: { story: {
        sector_ids: [ arts.id, bio.id ], primary_sector_id: bio.id,
        category_ids: [ teens.id ], primary_category_id: teens.id
      } }

      changes = pushed.find { |event| event[:name] == "update.story" }[:properties][:association_changes]
      expect(changes[:primary_sector]).to contain_exactly(
        { action: "added", type: "Sector", id: bio.id, label: "Bio" },
        { action: "removed", type: "Sector", id: arts.id, label: "Arts" }
      )
      expect(changes[:primary_category]).to eq([ { action: "added", type: "Category", id: teens.id, label: "Teens" } ])
      expect(changes[:sectors]).to eq([ { action: "added", type: "Sector", id: bio.id, label: "Bio" } ])
    end
  end
end
