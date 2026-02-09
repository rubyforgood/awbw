require "rails_helper"

RSpec.describe TaggingSearchService do
  let!(:sector) { create(:sector, :published, name: "Youth") }
  let!(:category_type) { create(:category_type, name: "Theme") }
  let!(:category) { create(:category, :published, name: "Healing", category_type: category_type) }

  let!(:workshop) { create(:workshop, :published, title: "Art for Healing") }

  before do
    create(:sectorable_item, sector: sector, sectorable: workshop)
    create(:categorizable_item, category: category, categorizable: workshop)
  end

  describe ".call" do
    context "when no filters are provided" do
      it "returns empty paginated collections for all types" do
        results = described_class.call(
          sector_names_all: nil,
          category_names_all: nil,
          pages: {},
          number_of_items_per_page: 9
        )

        expect(results).to be_a(Hash)

        results.each do |_type, collection|
          expect(collection).to respond_to(:total_entries)
          expect(collection.total_entries).to eq(0)
          expect(collection).to be_empty
        end
      end
    end

    context "when no sector_names_all or category_names_all are provided" do
      it "returns empty results for all taggable models" do
        result = described_class.call(
          sector_names_all: nil,
          category_names_all: nil
        )

        expect(result).to be_a(Hash)
        expect(result.keys).to match_array(Tag::TAGGABLE_META.keys)

        result.each do |_, collection|
          expect(collection).to eq([])
        end
      end
    end

    context "when filtering by sector" do
      it "returns matching tagged content" do
        results = described_class.call(
          sector_names_all: "Youth",
          category_names_all: nil,
          pages: {},
          number_of_items_per_page: 9
        )

        expect(results[:workshops].map(&:title)).to include("Art for Healing")
      end
    end

    context "when filtering by category" do
      it "returns matching tagged content" do
        results = described_class.call(
          sector_names_all: nil,
          category_names_all: "Healing",
          pages: {},
          number_of_items_per_page: 9
        )

        expect(results[:workshops].map(&:title)).to include("Art for Healing")
      end
    end

    context "when filters do not match anything" do
      it "returns empty collections" do
        results = described_class.call(
          sector_names_all: "Nonexistent",
          category_names_all: nil,
          pages: {},
          number_of_items_per_page: 9
        )

        expect(results[:workshops]).to be_empty
        expect(results[:workshops].total_entries).to eq(0)
      end

      it "returns empty collections for partial/substring matches" do
        # Should NOT match "Youth" sector with partial search "You"
        results = described_class.call(
          sector_names_all: "You",
          category_names_all: nil,
          pages: {},
          number_of_items_per_page: 9
        )

        expect(results[:workshops]).to be_empty

        # Should NOT match "Healing" category with partial search "Heal"
        results = described_class.call(
          sector_names_all: nil,
          category_names_all: "Heal",
          pages: {},
          number_of_items_per_page: 9
        )

        expect(results[:workshops]).to be_empty
      end
    end
  end
end
