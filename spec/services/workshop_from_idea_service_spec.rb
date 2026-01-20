# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkshopFromIdeaService do
  subject(:service) { described_class.new(workshop_idea, user: user) }

  let(:user) { create(:user) }
  let(:workshop_idea) { create(:workshop_idea, created_by: user, updated_by: user) }

  describe "#call" do
    let(:workshop) { service.call }

    it "returns a new Workshop" do
      expect(workshop).to be_a(Workshop)
      expect(workshop).to be_new_record
    end

    it "copies basic attributes from workshop_idea" do
      expect(workshop).to have_attributes(
        title: workshop_idea.title,
        objective: workshop_idea.objective,
        materials: workshop_idea.materials,
        windows_type_id: workshop_idea.windows_type_id,
        workshop_idea_id: workshop_idea.id,
        user_id: user.id
      )
    end

    it "sets the workshop as inactive by default" do
      expect(workshop.inactive).to be true
    end

    it "sets the workshop as not featured by default" do
      expect(workshop.featured).to be false
    end

    context "when workshop_idea has a primary_asset" do
      let(:workshop_idea) do
        create(:workshop_idea, created_by: user, updated_by: user).tap do |wi|
          wi.create_primary_asset!(file: fixture_file_upload("spec/fixtures/test_image.jpg", "image/jpeg"))
        end
      end

      it "duplicates the primary_asset to the workshop" do
        expect(workshop.primary_asset).to be_present
        expect(workshop.primary_asset).to be_a(PrimaryAsset)
        expect(workshop.primary_asset.file).to be_attached
      end
    end

    context "when workshop_idea has gallery_assets" do
      let(:workshop_idea) do
        create(:workshop_idea, created_by: user, updated_by: user).tap do |wi|
          wi.gallery_assets.create!(file: fixture_file_upload("spec/fixtures/test_image.jpg", "image/jpeg"))
          wi.gallery_assets.create!(file: fixture_file_upload("spec/fixtures/test_image.jpg", "image/jpeg"))
        end
      end

      it "duplicates all gallery_assets to the workshop" do
        expect(workshop.gallery_assets.size).to eq(2)
        workshop.gallery_assets.each do |asset|
          expect(asset).to be_a(GalleryAsset)
          expect(asset.file).to be_attached
        end
      end
    end

    context "when workshop_idea has both primary and gallery assets" do
      let(:workshop_idea) do
        create(:workshop_idea, created_by: user, updated_by: user).tap do |wi|
          wi.create_primary_asset!(file: fixture_file_upload("spec/fixtures/test_image.jpg", "image/jpeg"))
          wi.gallery_assets.create!(file: fixture_file_upload("spec/fixtures/test_image.jpg", "image/jpeg"))
        end
      end

      it "duplicates both asset types correctly" do
        expect(workshop.primary_asset).to be_a(PrimaryAsset)
        expect(workshop.gallery_assets.size).to eq(1)
        expect(workshop.gallery_assets.first).to be_a(GalleryAsset)
      end
    end
  end
end
