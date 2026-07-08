require 'rails_helper'

RSpec.describe Story, type: :model do
  it_behaves_like "author_creditable", factory: :story

  describe "#author_person" do
    let(:creator) { create(:user, :with_person) }
    let(:facilitator) { create(:person) }

    it "returns the explicitly chosen author when present" do
      story = create(:story, created_by: creator, author: facilitator)
      expect(story.author_person).to eq(facilitator)
    end

    it "falls back to the creating user's person when no author is set" do
      story = create(:story, created_by: creator, author: nil)
      expect(story.author_person).to eq(creator.person)
    end

    it "credits the author over the creator via author_credit" do
      story = create(:story, created_by: creator, author: facilitator,
                             author_credit_preference: "full_name")
      expect(story.author_credit).to eq(facilitator.full_name)
    end
  end

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

    context 'when the query matches a credited person name' do
      let(:creator) { create(:user, person: create(:person, first_name: 'Zephyrina', last_name: 'Quackenbush')) }
      let(:facilitator) { create(:person, first_name: 'Bartholomew', last_name: 'Snazzlepants') }
      let!(:authored_story) { create(:story, :published, title: 'No Name Match', created_by: creator, author: facilitator) }

      it 'finds stories by the explicit author name' do
        results = Story.search_by_params(query: 'Bartholomew')
        expect(results).to include(authored_story)
        expect(results).not_to include(published_story)
      end

      it "finds stories by the creating user's person name" do
        created_story = create(:story, :published, title: 'Creator Only', created_by: creator)
        results = Story.search_by_params(query: 'Zephyrina')
        expect(results).to include(created_story)
      end
    end
  end

  describe "#to_param" do
    it "is the id followed by the title slugged with hyphens, stripping bad URL characters" do
      story = create(:story, title: "My Great Story! #2 (2026)")
      expect(story.to_param).to eq("#{story.id}-my-great-story-2-2026")
    end

    it "tracks the title when it changes" do
      story = create(:story, title: "Original Title")
      story.update!(title: "Brand New Title")
      expect(story.to_param).to eq("#{story.id}-brand-new-title")
    end

    it "resolves back to the record via the leading id" do
      story = create(:story, title: "Some Story")
      expect(Story.find(story.to_param)).to eq(story)
    end
  end
end
