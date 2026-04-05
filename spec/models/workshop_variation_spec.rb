require "rails_helper"

RSpec.describe WorkshopVariation do
  it_behaves_like "author_creditable", factory: :workshop_variation

  describe "associations" do
    it { should belong_to(:workshop).optional }
    it { should belong_to(:windows_type).optional }
    it { should belong_to(:created_by).class_name("User").optional }
    it { should belong_to(:workshop_variation_idea).optional }
  end

  describe "validations" do
    subject { build(:workshop_variation) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:rhino_body) }
    it { should validate_presence_of(:windows_type_id) }
    it { should validate_presence_of(:author_credit_preference) }
    it { should validate_uniqueness_of(:name).scoped_to(:workshop_id).case_insensitive }
  end

  describe "#attach_assets_from_idea!" do
    let(:idea) { create(:workshop_variation_idea) }
    let(:variation) { create(:workshop_variation, workshop_variation_idea: idea) }

    before do
      create(:gallery_asset, :with_file, owner: idea)
      create(:gallery_asset, :with_file, owner: idea)
      create(:gallery_asset, :with_file, owner: idea)
    end

    it "promotes the first gallery asset to primary" do
      variation.attach_assets_from_idea!
      variation.reload

      expect(variation.primary_asset).to be_present
      expect(variation.primary_asset.file).to be_attached
    end

    it "keeps remaining gallery assets as gallery" do
      variation.attach_assets_from_idea!
      variation.reload

      expect(variation.gallery_assets.count).to eq(2)
      variation.gallery_assets.each do |asset|
        expect(asset.file).to be_attached
      end
    end

    it "appends idea assets after existing gallery assets" do
      create(:gallery_asset, :with_file, owner: variation)

      variation.attach_assets_from_idea!

      expect(variation.assets.count).to eq(4)
    end

    it "does nothing without a linked idea" do
      variation_without_idea = create(:workshop_variation, workshop_variation_idea: nil)
      expect { variation_without_idea.attach_assets_from_idea! }.not_to change { variation_without_idea.assets.count }
    end

    context "when user uploaded a primary asset" do
      before { create(:primary_asset, :with_file, owner: variation) }

      it "keeps the user-uploaded primary" do
        original_blob_id = variation.primary_asset.file.blob_id

        variation.attach_assets_from_idea!
        variation.reload

        expect(variation.primary_asset.file.blob_id).to eq(original_blob_id)
      end

      it "adds all idea assets as gallery" do
        variation.attach_assets_from_idea!
        variation.reload

        expect(variation.gallery_assets.count).to eq(3)
      end

      it "does not create a second primary asset" do
        variation.attach_assets_from_idea!
        variation.reload

        expect(variation.assets.where(type: "PrimaryAsset").count).to eq(1)
      end
    end

    context "when user uploaded gallery assets" do
      before { create(:gallery_asset, :with_file, owner: variation) }

      it "keeps user-uploaded gallery assets" do
        original_blob_id = variation.gallery_assets.first.file.blob_id

        variation.attach_assets_from_idea!
        variation.reload

        expect(variation.gallery_assets.map(&:file).map(&:blob_id)).to include(original_blob_id)
      end

      it "promotes first idea gallery to primary when no primary exists" do
        variation.attach_assets_from_idea!
        variation.reload

        expect(variation.primary_asset).to be_present
      end
    end
  end

  describe ".search_by_params" do
    let!(:variation_a) { create(:workshop_variation, name: "Watercolor Technique") }
    let!(:variation_b) { create(:workshop_variation, name: "Clay Sculpting") }

    it "returns all when no params" do
      results = WorkshopVariation.search_by_params({})
      expect(results).to include(variation_a, variation_b)
    end

    it "filters by query matching name" do
      results = WorkshopVariation.search_by_params(query: "Watercolor")
      expect(results).to include(variation_a)
      expect(results).not_to include(variation_b)
    end

    it "returns empty for non-matching query" do
      results = WorkshopVariation.search_by_params(query: "nonexistent")
      expect(results).not_to include(variation_a, variation_b)
    end
  end
end
