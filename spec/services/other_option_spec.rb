require "rails_helper"

RSpec.describe OtherOption do
  describe ".texts" do
    it "extracts the free text after the Other prefix" do
      expect(described_class.texts("Other: Equine therapy")).to eq([ "Equine therapy" ])
    end

    it "pulls the free text out of an answer joined with selected ids" do
      expect(described_class.texts("5, 12, Other: Equine therapy")).to eq([ "Equine therapy" ])
    end

    it "ignores a bare Other with no accompanying text" do
      expect(described_class.texts("5, Other")).to eq([])
    end

    it "ignores answers with no Other option" do
      expect(described_class.texts("5, 12")).to eq([])
    end

    it "returns nothing for a blank answer" do
      expect(described_class.texts(nil)).to eq([])
      expect(described_class.texts("")).to eq([])
    end

    it "matches the prefix case-insensitively" do
      expect(described_class.texts("other: Music therapy")).to eq([ "Music therapy" ])
    end
  end
end
