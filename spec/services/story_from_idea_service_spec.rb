# frozen_string_literal: true

require "rails_helper"

RSpec.describe StoryFromIdeaService do
  subject(:service) { described_class.new(story_idea, user: user) }

  let(:user) { create(:user) }
  let(:story_idea) { create(:story_idea, created_by: user, updated_by: user) }

  describe "#call" do
    let(:story) { service.call }

    it "returns a new Story" do
      expect(story).to be_a(Story)
      expect(story).to be_new_record
    end

    it "copies basic attributes from story_idea" do
      expect(story).to have_attributes(
        title: story_idea.title,
        body: story_idea.body,
        youtube_url: story_idea.youtube_url,
        windows_type_id: story_idea.windows_type_id,
        project_id: story_idea.project_id,
        workshop_id: story_idea.workshop_id,
        story_idea_id: story_idea.id,
        created_by_id: user.id,
        updated_by_id: user.id
      )
    end

    it "sets the story as unpublished by default" do
      expect(story.published).to be false
    end

    context "when story_idea has a primary_asset" do
      let(:story_idea) do
        create(:story_idea, created_by: user, updated_by: user).tap do |si|
          si.create_primary_asset!(file: fixture_file_upload("spec/fixtures/test_image.jpg", "image/jpeg"))
        end
      end

      it "duplicates the primary_asset to the story" do
        expect(story.primary_asset).to be_present
        expect(story.primary_asset).to be_a(PrimaryAsset)
        expect(story.primary_asset.file).to be_attached
      end
    end

    context "when story_idea has gallery_assets" do
      let(:story_idea) do
        create(:story_idea, created_by: user, updated_by: user).tap do |si|
          si.gallery_assets.create!(file: fixture_file_upload("spec/fixtures/test_image.jpg", "image/jpeg"))
          si.gallery_assets.create!(file: fixture_file_upload("spec/fixtures/test_image.jpg", "image/jpeg"))
        end
      end

      it "duplicates all gallery_assets to the story" do
        expect(story.gallery_assets.size).to eq(2)
        story.gallery_assets.each do |asset|
          expect(asset).to be_a(GalleryAsset)
          expect(asset.file).to be_attached
        end
      end
    end

    context "when story_idea has both primary and gallery assets" do
      let(:story_idea) do
        create(:story_idea, created_by: user, updated_by: user).tap do |si|
          si.create_primary_asset!(file: fixture_file_upload("spec/fixtures/test_image.jpg", "image/jpeg"))
          si.gallery_assets.create!(file: fixture_file_upload("spec/fixtures/test_image.jpg", "image/jpeg"))
        end
      end

      it "duplicates both asset types correctly" do
        expect(story.primary_asset).to be_a(PrimaryAsset)
        expect(story.gallery_assets.size).to eq(1)
        expect(story.gallery_assets.first).to be_a(GalleryAsset)
      end
    end
  end
end
