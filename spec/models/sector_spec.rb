require 'rails_helper'

RSpec.describe Sector, type: :model do
  describe ".taggings_presence" do
    let!(:tagged) { create(:sector) }
    let!(:untagged) { create(:sector) }

    before { create(:sectorable_item, sector: tagged) }

    it "returns only sectors with taggings for \"with\"" do
      expect(Sector.taggings_presence("with")).to contain_exactly(tagged)
    end

    it "returns only sectors without taggings for \"without\"" do
      expect(Sector.taggings_presence("without")).to contain_exactly(untagged)
    end

    it "returns all sectors for a blank value" do
      expect(Sector.taggings_presence("")).to contain_exactly(tagged, untagged)
    end
  end
end
