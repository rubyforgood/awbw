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

      expect(variation.primary_asset).to be_present
      expect(variation.primary_asset.file).to be_attached
    end

    it "keeps remaining gallery assets as gallery" do
      variation.attach_assets_from_idea!

      expect(variation.gallery_assets.count).to eq(2)
      variation.gallery_assets.each do |asset|
        expect(asset.file).to be_attached
      end
    end

    it "replaces existing assets" do
      create(:gallery_asset, :with_file, owner: variation)
      expect(variation.assets.count).to eq(1)

      variation.attach_assets_from_idea!

      expect(variation.assets.count).to eq(3)
    end

    it "does nothing without a linked idea" do
      variation_without_idea = create(:workshop_variation, workshop_variation_idea: nil)
      expect { variation_without_idea.attach_assets_from_idea! }.not_to change { variation_without_idea.assets.count }
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
