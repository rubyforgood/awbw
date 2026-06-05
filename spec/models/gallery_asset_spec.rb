require "rails_helper"

RSpec.describe GalleryAsset, type: :model do
  describe ".images" do
    it "returns only gallery assets with an attached image file" do
      with_image = create(:gallery_asset, :with_file)
      create(:gallery_asset) # no file attached

      expect(described_class.images).to contain_exactly(with_image)
    end
  end

  describe ".search_metadata" do
    let!(:tagged)   { create(:gallery_asset, :with_file, title: "Sunrise Workshop") }
    let!(:other)    { create(:gallery_asset, :with_file, title: "Evening Class") }

    it "matches on the editable title (case-insensitive)" do
      expect(described_class.images.search_metadata("sunrise")).to contain_exactly(tagged)
    end

    it "matches on the owner type" do
      workshop = create(:workshop)
      owned = create(:gallery_asset, :with_file, owner: workshop, title: "Untitled")

      expect(described_class.images.search_metadata("workshop")).to include(owned)
    end

    it "returns the full scope when the query is blank" do
      expect(described_class.images.search_metadata("")).to contain_exactly(tagged, other)
    end
  end
end
