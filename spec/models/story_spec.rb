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
      story.reload

      expect(story.primary_asset).to be_present
      expect(story.primary_asset.file).to be_attached
    end

    it "keeps remaining gallery assets as gallery" do
      story.attach_assets_from_idea!
      story.reload

      expect(story.gallery_assets.count).to eq(2)
      story.gallery_assets.each do |asset|
        expect(asset.file).to be_attached
      end
    end

    it "appends idea assets after existing gallery assets" do
      create(:gallery_asset, :with_file, owner: story)

      story.attach_assets_from_idea!

      expect(story.assets.count).to eq(4)
    end

    it "does nothing without a linked idea" do
      story_without_idea = create(:story, story_idea: nil)
      expect { story_without_idea.attach_assets_from_idea! }.not_to change { story_without_idea.assets.count }
    end

    context "when user uploaded a primary asset" do
      before { create(:primary_asset, :with_file, owner: story) }

      it "keeps the user-uploaded primary" do
        original_blob_id = story.primary_asset.file.blob_id

        story.attach_assets_from_idea!
        story.reload

        expect(story.primary_asset.file.blob_id).to eq(original_blob_id)
      end

      it "adds all idea assets as gallery" do
        story.attach_assets_from_idea!
        story.reload

        expect(story.gallery_assets.count).to eq(3)
      end

      it "does not create a second primary asset" do
        story.attach_assets_from_idea!
        story.reload

        expect(story.assets.where(type: "PrimaryAsset").count).to eq(1)
      end
    end

    context "when user uploaded gallery assets" do
      before { create(:gallery_asset, :with_file, owner: story) }

      it "keeps user-uploaded gallery assets" do
        original_blob_id = story.gallery_assets.first.file.blob_id

        story.attach_assets_from_idea!
        story.reload

        expect(story.gallery_assets.map(&:file).map(&:blob_id)).to include(original_blob_id)
      end

      it "promotes first idea gallery to primary when no primary exists" do
        story.attach_assets_from_idea!
        story.reload

        expect(story.primary_asset).to be_present
      end
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

    it 'filters by organization_id' do
      organization = create(:organization)
      org_story = create(:story, organization: organization)

      results = Story.search_by_params(organization_id: organization.id)
      expect(results).to include(org_story)
      expect(results).not_to include(published_story, draft_story, old_story)
    end
  end

  describe "positioning of featured stories" do
    it "assigns sequential positions within the featured set as stories are created" do
      first = create(:story, :featured)
      second = create(:story, :featured)

      expect([ first.position, second.position ]).to eq([ 1, 2 ])
    end

    it "scopes positions to featured, so non-featured stories keep their own sequence" do
      featured = create(:story, :featured)
      non_featured = create(:story)

      expect(featured.position).to eq(1)
      expect(non_featured.position).to eq(1)
    end

    it "reorders the featured set when a position is assigned" do
      first = create(:story, :featured)
      second = create(:story, :featured)
      third = create(:story, :featured)

      third.update!(position: 1)

      expect(first.reload.position).to eq(2)
      expect(second.reload.position).to eq(3)
      expect(third.reload.position).to eq(1)
    end

    it "orders the featured scope by position" do
      first = create(:story, :featured, :published)
      second = create(:story, :featured, :published)
      second.update!(position: 1)

      expect(Story.featured.order(:position)).to eq([ second, first ])
    end
  end
end
