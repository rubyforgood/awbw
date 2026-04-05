require 'rails_helper'

RSpec.describe Story, type: :model do
  it_behaves_like "author_creditable", factory: :story

  describe "#attach_assets_from_idea!" do
    let(:idea) { create(:story_idea) }
    let(:story) { create(:story, story_idea: idea) }

    before do
      create(:gallery_asset, :with_file, owner: idea)
      create(:gallery_asset, :with_file, owner: idea)
      create(:gallery_asset, :with_file, owner: idea)
    end

    it "promotes the first gallery asset to primary" do
      story.attach_assets_from_idea!

      expect(story.primary_asset).to be_present
      expect(story.primary_asset.file).to be_attached
    end

    it "keeps remaining gallery assets as gallery" do
      story.attach_assets_from_idea!

      expect(story.gallery_assets.count).to eq(2)
      story.gallery_assets.each do |asset|
        expect(asset.file).to be_attached
      end
    end

    it "replaces existing assets" do
      create(:gallery_asset, :with_file, owner: story)
      expect(story.assets.count).to eq(1)

      story.attach_assets_from_idea!

      expect(story.assets.count).to eq(3)
    end

    it "does nothing without a linked idea" do
      story_without_idea = create(:story, story_idea: nil)
      expect { story_without_idea.attach_assets_from_idea! }.not_to change { story_without_idea.assets.count }
    end
  end

  describe '.search_by_params' do
    let!(:published_story) { create(:story, :published, title: 'Healing Through Art') }
    let!(:draft_story) { create(:story, title: 'Unpublished Draft', published: false) }
    let!(:old_story) do
      create(:story, :published, title: 'Last Year Story').tap do |s|
        s.update_columns(created_at: Date.new(2025, 5, 1))
      end
    end

    it 'returns all when no params' do
      results = Story.search_by_params({})
      expect(results).to include(published_story, draft_story, old_story)
    end

    it 'filters by title' do
      results = Story.search_by_params(title: 'Healing')
      expect(results).to include(published_story)
      expect(results).not_to include(draft_story)
    end

    it 'filters by published param' do
      results = Story.search_by_params(published: 'true')
      expect(results).to include(published_story, old_story)
      expect(results).not_to include(draft_story)
    end

    it 'filters by year' do
      results = Story.search_by_params(year: '2025')
      expect(results).to include(old_story)
      expect(results).not_to include(published_story)
    end

    it 'chains title and published filters' do
      results = Story.search_by_params(title: 'Healing', published: 'true')
      expect(results).to include(published_story)
      expect(results).not_to include(draft_story, old_story)
    end
  end
end
